import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/api_keys.dart';
import '../domain/b4y_models.dart';

abstract class B4yRepository {
  Future<B4ySampleData> loadSampleData();
}

class AssetB4yRepository implements B4yRepository {
  const AssetB4yRepository();

  @override
  Future<B4ySampleData> loadSampleData() async {
    final rawJson = await rootBundle.loadString('assets/data/sample_b4y.json');
    return B4ySampleData.fromJson(jsonDecode(rawJson) as Map<String, dynamic>);
  }
}

class ApiBackedB4yRepository implements B4yRepository {
  const ApiBackedB4yRepository({
    required this.keys,
    this.userLocation,
    this.client,
    this.fallback = const AssetB4yRepository(),
  });

  static const _siheungCenter = LatLng(37.3516, 126.7427);
  static const _gyeonggiAreaCode = '31';
  static const _siheungSigunguCode = '14';
  static const _ansanSigunguCode = '15';

  final ApiKeys keys;
  final LatLng? userLocation;
  final http.Client? client;
  final B4yRepository fallback;

  @override
  Future<B4ySampleData> loadSampleData() async {
    final fallbackData = await fallback.loadSampleData();
    if (!keys.hasGbisApiKey && !keys.hasOdsayApiKey && !keys.hasTourApiKey) {
      return fallbackData;
    }

    final ownedClient = client ?? http.Client();
    final searchCenter = userLocation ?? _siheungCenter;
    try {
      final routeLoad = keys.hasGbisApiKey
          ? await _loadGbisRoutes(ownedClient, searchCenter)
          : keys.hasOdsayApiKey
          ? await _loadOdsayRoutes(ownedClient, searchCenter)
          : _RouteLoadResult(
              routes: fallbackData.routes,
              stops: fallbackData.stops,
            );
      final routes = routeLoad.routes.isEmpty
          ? fallbackData.routes
          : routeLoad.routes;
      final resolvedStops = routeLoad.routes.isEmpty
          ? fallbackData.stops
          : routeLoad.stops.isEmpty
          ? fallbackData.stops
          : routeLoad.stops;
      final nearbyRoutes = _routesAtNearestStopPair(
        routes,
        resolvedStops,
        searchCenter,
      );
      final touristSpots = keys.hasTourApiKey
          ? await _loadTourApiSpots(
              ownedClient,
              resolvedStops,
              nearbyRoutes,
              searchCenter,
            )
          : fallbackData.touristSpots;

      return B4ySampleData(
        stops: resolvedStops,
        routes: nearbyRoutes.isEmpty ? routes : nearbyRoutes,
        routePhotoClusters: fallbackData.routePhotoClusters,
        touristSpots: touristSpots.isEmpty
            ? fallbackData.touristSpots
            : touristSpots,
        reviews: fallbackData.reviews,
        missions: fallbackData.missions,
        galleryPhotos: fallbackData.galleryPhotos,
      );
    } on Object {
      if (client != null) {
        rethrow;
      }
      return fallbackData;
    } finally {
      if (client == null) {
        ownedClient.close();
      }
    }
  }

  Future<List<BusRoute>> searchRegionalRoutes(
    String query, {
    List<BusRoute> fallbackRoutes = const [],
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final ownedClient = client ?? http.Client();
    try {
      final routes = keys.hasOdsayApiKey
          ? await _searchOdsayRegionalRoutes(ownedClient, normalizedQuery)
          : keys.hasGbisApiKey
          ? await _searchGbisRegionalRoutes(ownedClient, normalizedQuery)
          : const <BusRoute>[];
      if (routes.isNotEmpty) {
        return routes;
      }
    } on Object {
      if (client != null) {
        rethrow;
      }
    } finally {
      if (client == null) {
        ownedClient.close();
      }
    }

    return _filterFallbackRegionalRoutes(fallbackRoutes, normalizedQuery);
  }

  Future<_RouteLoadResult> _loadOdsayRoutes(
    http.Client client,
    LatLng searchCenter,
  ) async {
    final searchUri = Uri.https('api.odsay.com', '/v1/api/pointBusStation', {
      'apiKey': keys.odsayApiKey,
      'x': '${searchCenter.longitude}',
      'y': '${searchCenter.latitude}',
      'radius': '500',
      'output': 'json',
    });
    final search = await _getJson(client, searchUri);
    final busIds = _asList(search['result']?['lane'])
        .expand((station) => _asList(station['busList']))
        .map((bus) => _stringValue(bus['busID']))
        .where((busId) => busId.isNotEmpty)
        .toSet();
    final loadedRoutes = <_LoadedRoute>[];

    for (final busId in busIds) {
      final route = await _loadOdsayRouteDetail(client, busId);
      if (route != null) {
        loadedRoutes.add(route);
      }
    }
    return _RouteLoadResult(
      routes: loadedRoutes.map((loaded) => loaded.route).toList(),
      stops: _uniqueStops(loadedRoutes.expand((loaded) => loaded.stops)),
    );
  }

  Future<_LoadedRoute?> _loadOdsayRouteDetail(
    http.Client client,
    String busId,
  ) async {
    final detailUri = Uri.https('api.odsay.com', '/v1/api/busLaneDetail', {
      'apiKey': keys.odsayApiKey,
      'busID': busId,
      'output': 'json',
    });
    final detail = await _getJson(client, detailUri);
    final result = detail['result'] as Map<String, dynamic>?;
    if (result == null) {
      return null;
    }

    final stations = _asList(result['station'])
        .where((station) => _latLngFromApi(station['y'], station['x']) != null)
        .toList();
    if (stations.length < 2) {
      return null;
    }

    final stops = stations.map((station) {
      final id = 'odsay_stop_${_stringValue(station['stationID'])}';
      return BusStop(
        id: id,
        name: _stringValue(station['stationName']).isEmpty
            ? _stringValue(station['stationNameKor'])
            : _stringValue(station['stationName']),
        position: _latLngFromApi(station['y'], station['x'])!,
        sequence: _intValue(station['idx']) ?? 0,
      );
    }).toList();

    final roadShape = await _loadRoadShape(
      client,
      stops.map((stop) => stop.position).toList(),
    );
    final shape = roadShape.length >= 2
        ? roadShape
        : stops.map((stop) => stop.position).toList();
    final turnaroundIndex = _intValue(result['turningPointIdx']) ?? -1;
    final hasDirectionSplit =
        turnaroundIndex > 0 && turnaroundIndex < stops.length - 1;
    final upStops = hasDirectionSplit
        ? stops.sublist(0, turnaroundIndex + 1)
        : stops;
    final downStops = hasDirectionSplit
        ? stops.sublist(turnaroundIndex)
        : stops.reversed.toList();
    final splitShapes = hasDirectionSplit
        ? _splitShapeAtStop(shape, stops[turnaroundIndex].position)
        : (shape, shape.reversed.toList());
    final route = BusRoute(
      id: 'odsay_route_$busId',
      number: _stringValue(result['busNo']).isEmpty
          ? busId
          : _stringValue(result['busNo']),
      destination: _stringValue(result['busEndPoint']).isEmpty
          ? '종점 방면'
          : _stringValue(result['busEndPoint']),
      routeType: _firstNonEmpty([
        result['busType'],
        result['busTypeName'],
        result['type'],
      ]),
      directions: [
        RouteDirection(
          id: 'up',
          name: '상행',
          destination: '${_stringValue(result['busEndPoint'])} 방면',
          stopIds: upStops.map((stop) => stop.id).toList(),
          shape: splitShapes.$1,
        ),
        RouteDirection(
          id: 'down',
          name: '하행',
          destination: '${_stringValue(result['busStartPoint'])} 방면',
          stopIds: downStops.map((stop) => stop.id).toList(),
          shape: splitShapes.$2,
        ),
      ],
    );
    return _LoadedRoute(route: route, stops: stops);
  }

  Future<List<BusRoute>> _searchOdsayRegionalRoutes(
    http.Client client,
    String query,
  ) async {
    final uri = Uri.https('api.odsay.com', '/v1/api/searchBusLane', {
      'apiKey': keys.odsayApiKey,
      'busNo': query,
      'CID': '1000',
      'displayCnt': '100',
      'output': 'json',
    });
    final json = await _getJson(client, uri);
    final routes = <BusRoute>[];
    for (final lane in _asList(json['result']?['lane'])) {
      final busId = _stringValue(lane['busID']);
      if (busId.isEmpty) {
        continue;
      }
      final loaded = await _loadOdsayRouteDetail(client, busId);
      if (loaded == null || !_routePassesSiheungOrAnsan(loaded.stops)) {
        continue;
      }
      routes.add(loaded.route);
    }
    return _uniqueRoutes(routes);
  }

  Future<_RouteLoadResult> _loadGbisRoutes(
    http.Client client,
    LatLng searchCenter,
  ) async {
    final nearbyStations = await _loadGbisNearbyStations(client, searchCenter);
    final routeSummaries = <_GbisRouteSummary>[];
    final seenRouteIds = <String>{};

    for (final station in nearbyStations) {
      final stationRoutes = await _loadGbisStationRoutes(
        client,
        station.stationId,
      );
      for (final route in stationRoutes) {
        if (seenRouteIds.add(route.routeId)) {
          routeSummaries.add(route);
        }
      }
    }

    final loadedRoutes = <_LoadedRoute>[];
    for (final summary in routeSummaries) {
      final route = await _loadGbisRoute(client, summary);
      if (route != null) {
        loadedRoutes.add(route);
      }
    }
    return _RouteLoadResult(
      routes: loadedRoutes.map((loaded) => loaded.route).toList(),
      stops: _uniqueStops(loadedRoutes.expand((loaded) => loaded.stops)),
    );
  }

  Future<List<_GbisStationSummary>> _loadGbisNearbyStations(
    http.Client client,
    LatLng searchCenter,
  ) async {
    final uri = Uri.https(
      'apis.data.go.kr',
      '/6410000/busstationservice/v2/getBusStationAroundListv2',
      {
        'serviceKey': keys.gbisApiKey,
        'x': '${searchCenter.longitude}',
        'y': '${searchCenter.latitude}',
        'format': 'json',
        'pageNo': '1',
        'numOfRows': '50',
      },
    );
    final json = await _getJson(client, uri);
    final stations =
        _gbisItems(json, 'busStationList')
            .where(
              (station) =>
                  _stringValue(station['stationId']).isNotEmpty &&
                  _latLngFromApi(station['y'], station['x']) != null,
            )
            .map(
              (station) => _GbisStationSummary(
                stationId: _stringValue(station['stationId']),
                distanceMeters: _intValue(station['distance']) ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return stations;
  }

  Future<List<_GbisRouteSummary>> _loadGbisStationRoutes(
    http.Client client,
    String stationId,
  ) async {
    final uri = Uri.https(
      'apis.data.go.kr',
      '/6410000/busstationservice/v2/getBusStationViaRouteListv2',
      {
        'serviceKey': keys.gbisApiKey,
        'stationId': stationId,
        'format': 'json',
        'pageNo': '1',
        'numOfRows': '50',
      },
    );
    final json = await _getJson(client, uri);
    return _gbisItems(json, 'busRouteList')
        .where((route) => _stringValue(route['routeId']).isNotEmpty)
        .map(
          (route) => _GbisRouteSummary(
            routeId: _stringValue(route['routeId']),
            routeName: _stringValue(route['routeName']),
            routeDestName: _stringValue(route['routeDestName']),
            routeType: _firstNonEmpty([
              route['routeTypeName'],
              route['routeTypeCd'],
              route['routeType'],
            ]),
          ),
        )
        .toList();
  }

  Future<List<BusRoute>> _searchGbisRegionalRoutes(
    http.Client client,
    String query,
  ) async {
    final uri = Uri.https(
      'apis.data.go.kr',
      '/6410000/busrouteservice/v2/getBusRouteListv2',
      {'serviceKey': keys.gbisApiKey, 'keyword': query, 'format': 'json'},
    );
    final json = await _getJson(client, uri);
    final routes = <BusRoute>[];
    for (final route in _gbisItems(json, 'busRouteList')) {
      final routeId = _stringValue(route['routeId']);
      if (routeId.isEmpty) {
        continue;
      }
      final summary = _GbisRouteSummary(
        routeId: routeId,
        routeName: _stringValue(route['routeName']),
        routeDestName: _stringValue(route['routeDestName']),
        routeType: _firstNonEmpty([
          route['routeTypeName'],
          route['routeTypeCd'],
          route['routeType'],
        ]),
      );
      final loaded = await _loadGbisRoute(client, summary);
      if (loaded == null || !_routePassesSiheungOrAnsan(loaded.stops)) {
        continue;
      }
      routes.add(loaded.route);
    }
    return _uniqueRoutes(routes);
  }

  Future<_LoadedRoute?> _loadGbisRoute(
    http.Client client,
    _GbisRouteSummary summary,
  ) async {
    final routeInfo = await _loadGbisRouteInfo(client, summary.routeId);
    final stops = await _loadGbisRouteStops(client, summary.routeId);
    if (stops.length < 2) {
      return null;
    }

    final routeShape = await _loadGbisRouteLine(client, summary.routeId);
    final shape = routeShape.length >= 2
        ? routeShape
        : stops.map((stop) => stop.position).toList();
    final destination = routeInfo.endStationName.isNotEmpty
        ? routeInfo.endStationName
        : summary.routeDestName.isNotEmpty
        ? summary.routeDestName
        : '종점';
    final startName = routeInfo.startStationName.isNotEmpty
        ? routeInfo.startStationName
        : stops.first.name;
    final routeNumber = routeInfo.routeName.isNotEmpty
        ? routeInfo.routeName
        : summary.routeName.isNotEmpty
        ? summary.routeName
        : summary.routeId;
    final routeType = routeInfo.routeType.isNotEmpty
        ? routeInfo.routeType
        : summary.routeType;
    final turnaroundIndex = stops.indexWhere((stop) => stop.isTurnaround);
    final hasDirectionSplit =
        turnaroundIndex > 0 && turnaroundIndex < stops.length - 1;
    final upStops = hasDirectionSplit
        ? stops.sublist(0, turnaroundIndex + 1)
        : stops;
    final downStops = hasDirectionSplit
        ? stops.sublist(turnaroundIndex)
        : stops.reversed.toList();
    final splitShapes = hasDirectionSplit
        ? _splitShapeAtStop(shape, stops[turnaroundIndex].position)
        : (shape, shape.reversed.toList());

    final route = BusRoute(
      id: 'gbis_route_${summary.routeId}',
      number: routeNumber,
      destination: destination,
      routeType: routeType,
      directions: [
        RouteDirection(
          id: 'up',
          name: '상행',
          destination: '$destination 방면',
          stopIds: upStops.map((stop) => stop.id).toList(),
          shape: splitShapes.$1,
        ),
        RouteDirection(
          id: 'down',
          name: '하행',
          destination: '$startName 방면',
          stopIds: downStops.map((stop) => stop.id).toList(),
          shape: splitShapes.$2,
        ),
      ],
    );
    return _LoadedRoute(route: route, stops: stops);
  }

  Future<_GbisRouteInfo> _loadGbisRouteInfo(
    http.Client client,
    String routeId,
  ) async {
    final uri = Uri.https(
      'apis.data.go.kr',
      '/6410000/busrouteservice/v2/getBusRouteInfoItemv2',
      {'serviceKey': keys.gbisApiKey, 'routeId': routeId, 'format': 'json'},
    );
    final json = await _getJson(client, uri);
    final info = _gbisItems(json, 'busRouteInfoItem').firstOrNull;
    if (info == null) {
      return const _GbisRouteInfo();
    }
    return _GbisRouteInfo(
      routeName: _stringValue(info['routeName']),
      startStationName: _stringValue(info['startStationName']),
      endStationName: _stringValue(info['endStationName']),
      routeType: _firstNonEmpty([
        info['routeTypeName'],
        info['routeTypeCd'],
        info['routeType'],
      ]),
    );
  }

  Future<List<BusStop>> _loadGbisRouteStops(
    http.Client client,
    String routeId,
  ) async {
    final items = await _getGbisPagedItems(
      client,
      '/6410000/busrouteservice/v2/getBusRouteStationListv2',
      {'routeId': routeId},
      'busRouteStationList',
    );
    final stops =
        items
            .map((station) {
              final position = _latLngFromApi(station['y'], station['x']);
              if (position == null ||
                  _stringValue(station['stationId']).isEmpty) {
                return null;
              }
              return BusStop(
                id: 'gbis_stop_${_stringValue(station['stationId'])}',
                name: _stringValue(station['stationName']).isEmpty
                    ? '정류장 ${_stringValue(station['stationId'])}'
                    : _stringValue(station['stationName']),
                position: position,
                sequence: _intValue(station['stationSeq']) ?? 0,
                isTurnaround:
                    _stringValue(station['turnYn']).toUpperCase() == 'Y',
              );
            })
            .whereType<BusStop>()
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return stops;
  }

  Future<List<LatLng>> _loadGbisRouteLine(
    http.Client client,
    String routeId,
  ) async {
    final items = await _getGbisPagedItems(
      client,
      '/6410000/busrouteservice/v2/getBusRouteLineListv2',
      {'routeId': routeId},
      'busRouteLineList',
    );
    final points =
        items
            .map((point) {
              final position = _latLngFromApi(point['y'], point['x']);
              if (position == null) {
                return null;
              }
              return _GbisLinePoint(
                sequence: _intValue(point['lineSeq']) ?? 0,
                position: position,
              );
            })
            .whereType<_GbisLinePoint>()
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return points.map((point) => point.position).toList();
  }

  Future<List<LatLng>> _loadRoadShape(
    http.Client client,
    List<LatLng> waypoints,
  ) async {
    final validWaypoints = waypoints
        .where(
          (point) =>
              point.latitude.isFinite &&
              point.longitude.isFinite &&
              point.latitude >= -90 &&
              point.latitude <= 90 &&
              point.longitude >= -180 &&
              point.longitude <= 180,
        )
        .toList();
    if (validWaypoints.length < 2) {
      return const [];
    }

    final coordinates = validWaypoints
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/$coordinates',
      {'geometries': 'geojson', 'overview': 'full', 'steps': 'false'},
    );

    try {
      final json = await _getJson(client, uri);
      final route = _asList(json['routes']).firstOrNull;
      final coordinates = route is Map<String, dynamic>
          ? _asList(route['geometry']?['coordinates'])
          : const [];
      return coordinates
          .map((coordinate) {
            final pair = _asList(coordinate);
            if (pair.length < 2) {
              return null;
            }
            return _latLngFromApi(pair[1], pair[0]);
          })
          .whereType<LatLng>()
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<List<TouristSpot>> _loadTourApiSpots(
    http.Client client,
    List<BusStop> stops,
    List<BusRoute> routes,
    LatLng searchCenter,
  ) async {
    final items = await _loadTourApiRegionalItems(client);
    if (items.isEmpty) {
      return const [];
    }

    final routeIds = routes.map((route) => route.id).toList();
    return items
        .map((item) {
          final position = _latLngFromApi(item['mapy'], item['mapx']);
          if (position == null) {
            return null;
          }
          final nearestStop = _nearestStop(position, stops, searchCenter);
          final id = _stringValue(item['contentid']).isEmpty
              ? 'tour_${item.hashCode}'
              : 'tour_${_stringValue(item['contentid'])}';
          final imageUrl = _tourImageUrl(item);
          final address = [item['addr1'], item['addr2']]
              .map((part) => _stringValue(part).trim())
              .where((part) => part.isNotEmpty)
              .join(' ');
          return TouristSpot(
            id: id,
            name: _stringValue(item['title']).isEmpty
                ? '이름 없는 관광지'
                : _stringValue(item['title']),
            description: '',
            address: address,
            position: position,
            heroImageUrl: imageUrl,
            nearestStopId: nearestStop.id,
            routeIds: routeIds.isEmpty ? const [] : routeIds,
          );
        })
        .whereType<TouristSpot>()
        .toList();
  }

  Future<List<dynamic>> _loadTourApiRegionalItems(http.Client client) async {
    final items = <dynamic>[];
    for (final sigunguCode in const [_siheungSigunguCode, _ansanSigunguCode]) {
      items.addAll(
        await _getTourApiPagedItems(client, {
          'areaCode': _gyeonggiAreaCode,
          'sigunguCode': sigunguCode,
          'contentTypeId': '12',
          'arrange': 'A',
        }),
      );
    }
    return items;
  }

  Future<Map<String, dynamic>> _getJson(http.Client client, Uri uri) async {
    final response = await client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('API request failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getGbisPagedItems(
    http.Client client,
    String path,
    Map<String, String> queryParameters,
    String itemKey, {
    int pageSize = 100,
    int maxPages = 20,
  }) async {
    final items = <dynamic>[];
    for (var page = 1; page <= maxPages; page++) {
      final uri = Uri.https('apis.data.go.kr', path, {
        'serviceKey': keys.gbisApiKey,
        'format': 'json',
        'pageNo': '$page',
        'numOfRows': '$pageSize',
        ...queryParameters,
      });
      final json = await _getJson(client, uri);
      final pageItems = _gbisItems(json, itemKey);
      items.addAll(pageItems);

      final totalCount = _gbisTotalCount(json);
      if (totalCount != null) {
        if (items.length >= totalCount) {
          break;
        }
        continue;
      }
      if (pageItems.length < pageSize) {
        break;
      }
    }
    return items;
  }

  Future<List<dynamic>> _getTourApiPagedItems(
    http.Client client,
    Map<String, String> queryParameters, {
    int pageSize = 100,
    int maxPages = 20,
  }) async {
    final items = <dynamic>[];
    for (var page = 1; page <= maxPages; page++) {
      final uri =
          Uri.https('apis.data.go.kr', '/B551011/KorService2/areaBasedList2', {
            'serviceKey': keys.tourApiKey,
            'MobileOS': 'ETC',
            'MobileApp': 'B4Y',
            '_type': 'json',
            'numOfRows': '$pageSize',
            'pageNo': '$page',
            ...queryParameters,
          });
      final json = await _getJson(client, uri);
      final pageItems = _extractTourItems(json);
      items.addAll(pageItems);

      final totalCount = _tourTotalCount(json);
      if (totalCount != null) {
        if (items.length >= totalCount) {
          break;
        }
        continue;
      }
      if (pageItems.length < pageSize) {
        break;
      }
    }
    return items;
  }

  List<dynamic> _extractTourItems(Map<String, dynamic> json) {
    final items = json['response']?['body']?['items'];
    final item = items is Map<String, dynamic> ? items['item'] : null;
    return _asList(item);
  }

  int? _tourTotalCount(Map<String, dynamic> json) {
    return _intValue(json['response']?['body']?['totalCount']);
  }

  List<dynamic> _gbisItems(Map<String, dynamic> json, String key) {
    final value =
        json['response']?['msgBody']?[key] ??
        json['msgBody']?[key] ??
        json['response']?['body']?[key] ??
        json['body']?[key] ??
        json[key];
    return _asList(value);
  }

  int? _gbisTotalCount(Map<String, dynamic> json) {
    final value =
        json['response']?['msgHeader']?['totalCount'] ??
        json['msgHeader']?['totalCount'] ??
        json['response']?['body']?['totalCount'] ??
        json['body']?['totalCount'] ??
        json['totalCount'];
    return _intValue(value);
  }

  BusStop _nearestStop(
    LatLng position,
    List<BusStop> stops,
    LatLng searchCenter,
  ) {
    if (stops.isEmpty) {
      return BusStop(
        id: 'api_virtual_stop',
        name: '근처 정류장',
        position: searchCenter,
        sequence: 0,
      );
    }
    const distance = Distance();
    final sorted = [...stops]
      ..sort(
        (a, b) => distance(
          position,
          a.position,
        ).compareTo(distance(position, b.position)),
      );
    return sorted.first;
  }

  List<BusStop> _uniqueStops(Iterable<BusStop> stops) {
    final byId = <String, BusStop>{};
    for (final stop in stops) {
      byId.putIfAbsent(stop.id, () => stop);
    }
    return byId.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }
}

List<BusRoute> _routesAtNearestStopPair(
  List<BusRoute> routes,
  List<BusStop> stops,
  LatLng searchCenter,
) {
  if (routes.isEmpty || stops.isEmpty) {
    return routes;
  }

  const distance = Distance();
  final orderedStops = [...stops]
    ..sort(
      (a, b) => distance(
        searchCenter,
        a.position,
      ).compareTo(distance(searchCenter, b.position)),
    );
  final nearestStop = orderedStops.first;
  const oppositeStopRadiusMeters = 150.0;
  final oppositeStop = orderedStops
      .skip(1)
      .where(
        (stop) =>
            distance(nearestStop.position, stop.position) <=
            oppositeStopRadiusMeters,
      )
      .firstOrNull;
  final stopIds = {nearestStop.id, if (oppositeStop != null) oppositeStop.id};

  return routes
      .where(
        (route) => route.directions.any(
          (direction) => direction.stopIds.any(stopIds.contains),
        ),
      )
      .toList();
}

List<BusRoute> _filterFallbackRegionalRoutes(
  List<BusRoute> routes,
  String query,
) {
  final normalizedQuery = _normalizeSearchText(query);
  return routes
      .where(
        (route) => _normalizeSearchText(
          '${route.number} ${route.destination}',
        ).contains(normalizedQuery),
      )
      .toList();
}

List<BusRoute> _uniqueRoutes(Iterable<BusRoute> routes) {
  final byId = <String, BusRoute>{};
  for (final route in routes) {
    if (route.id.isEmpty || route.number.isEmpty) {
      continue;
    }
    byId.putIfAbsent(route.id, () => route);
  }
  return byId.values.toList()
    ..sort((a, b) => _routeNumberSortKey(a).compareTo(_routeNumberSortKey(b)));
}

bool _routePassesSiheungOrAnsan(List<BusStop> stops) {
  return stops.any((stop) {
    final name = _normalizeSearchText(stop.name);
    return name.contains('시흥') ||
        name.contains('안산') ||
        _isInSiheungOrAnsan(stop.position);
  });
}

bool _isInSiheungOrAnsan(LatLng point) {
  final lat = point.latitude;
  final lng = point.longitude;
  final inSiheung =
      lat >= 37.29 && lat <= 37.48 && lng >= 126.68 && lng <= 126.84;
  final inAnsanUrban =
      lat >= 37.25 && lat <= 37.38 && lng >= 126.72 && lng <= 126.93;
  final inDaebudo =
      lat >= 37.18 && lat <= 37.31 && lng >= 126.54 && lng < 126.72;
  return inSiheung || inAnsanUrban || inDaebudo;
}

String _routeNumberSortKey(BusRoute route) {
  return route.number.padLeft(8, '0');
}

String _normalizeSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

class _RouteLoadResult {
  const _RouteLoadResult({required this.routes, required this.stops});

  final List<BusRoute> routes;
  final List<BusStop> stops;
}

class _LoadedRoute {
  const _LoadedRoute({required this.route, required this.stops});

  final BusRoute route;
  final List<BusStop> stops;
}

class _GbisStationSummary {
  const _GbisStationSummary({
    required this.stationId,
    required this.distanceMeters,
  });

  final String stationId;
  final int distanceMeters;
}

class _GbisRouteSummary {
  const _GbisRouteSummary({
    required this.routeId,
    required this.routeName,
    required this.routeDestName,
    required this.routeType,
  });

  final String routeId;
  final String routeName;
  final String routeDestName;
  final String routeType;
}

class _GbisRouteInfo {
  const _GbisRouteInfo({
    this.routeName = '',
    this.startStationName = '',
    this.endStationName = '',
    this.routeType = '',
  });

  final String routeName;
  final String startStationName;
  final String endStationName;
  final String routeType;
}

class _GbisLinePoint {
  const _GbisLinePoint({required this.sequence, required this.position});

  final int sequence;
  final LatLng position;
}

(List<LatLng>, List<LatLng>) _splitShapeAtStop(
  List<LatLng> shape,
  LatLng stopPosition,
) {
  if (shape.length < 3) {
    return (shape, shape);
  }
  const distance = Distance();
  var splitIndex = 0;
  var splitDistance = distance(stopPosition, shape.first);
  for (var index = 1; index < shape.length; index++) {
    final nextDistance = distance(stopPosition, shape[index]);
    if (nextDistance < splitDistance) {
      splitIndex = index;
      splitDistance = nextDistance;
    }
  }
  if (splitIndex == 0 || splitIndex == shape.length - 1) {
    return (shape, shape);
  }
  return (shape.sublist(0, splitIndex + 1), shape.sublist(splitIndex));
}

List<dynamic> _asList(dynamic value) {
  if (value == null) {
    return const [];
  }
  if (value is List) {
    return value;
  }
  return [value];
}

String _stringValue(dynamic value) => value?.toString() ?? '';

String _firstNonEmpty(Iterable<dynamic> values) {
  for (final value in values) {
    final text = _stringValue(value).trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

int? _intValue(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(_stringValue(value));
}

double? _doubleValue(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(_stringValue(value));
}

LatLng? _latLngFromApi(dynamic latValue, dynamic lngValue) {
  final lat = _finiteDoubleValue(latValue);
  final lng = _finiteDoubleValue(lngValue);
  if (lat == null || lng == null) {
    return null;
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return null;
  }
  return LatLng(lat, lng);
}

double? _finiteDoubleValue(dynamic value) {
  final parsed = _doubleValue(value);
  if (parsed == null || !parsed.isFinite) {
    return null;
  }
  return parsed;
}

String _tourImageUrl(Map<String, dynamic> item) {
  final primary = _stringValue(item['firstimage']).trim();
  final secondary = _stringValue(item['firstimage2']).trim();
  final url = primary.isNotEmpty ? primary : secondary;
  if (url.isEmpty) {
    return 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80';
  }
  if (url.startsWith('http://')) {
    return 'https://${url.substring('http://'.length)}';
  }
  return url;
}
