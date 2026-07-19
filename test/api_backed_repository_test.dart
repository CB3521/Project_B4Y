import 'dart:convert';

import 'package:b4y/src/config/api_keys.dart';
import 'package:b4y/src/data/b4y_repository.dart';
import 'package:b4y/src/domain/b4y_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('ApiBackedB4yRepository maps ODsay and TourAPI responses', () async {
    final repository = ApiBackedB4yRepository(
      keys: const ApiKeys(
        odsayApiKey: 'odsay-key',
        gbisApiKey: '',
        tourApiKey: 'tour-key',
        kakaoMapKey: '',
      ),
      userLocation: const LatLng(37.55, 126.97),
      fallback: const _FallbackRepository(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/pointBusStation')) {
          expect(request.url.queryParameters['x'], '126.97');
          expect(request.url.queryParameters['y'], '37.55');
          return _jsonResponse({
            'result': {
              'lane': [
                {
                  'stationName': '근처 정류장',
                  'busList': [
                    {'busID': 123, 'busNo': '99'},
                  ],
                },
              ],
            },
          });
        }
        if (request.url.path.endsWith('/busLaneDetail')) {
          return _jsonResponse({
            'result': {
              'busID': 123,
              'busNo': '99',
              'busStartPoint': '출발지',
              'busEndPoint': '도착지',
              'turningPointIdx': 2,
              'station': [
                {
                  'idx': 1,
                  'stationID': 11,
                  'stationName': '첫 정류장',
                  'x': 126.7,
                  'y': 37.3,
                },
                {
                  'idx': 2,
                  'stationID': 12,
                  'stationName': '둘째 정류장',
                  'x': 126.8,
                  'y': 37.4,
                },
                {
                  'idx': 3,
                  'stationID': 13,
                  'stationName': '회차 정류장',
                  'x': 126.9,
                  'y': 37.5,
                },
                {
                  'idx': 4,
                  'stationID': 14,
                  'stationName': '맞은편 정류장',
                  'x': 126.81,
                  'y': 37.41,
                },
              ],
            },
          });
        }
        if (request.url.host == 'router.project-osrm.org') {
          expect(request.url.path, contains('/route/v1/driving/'));
          expect(request.url.queryParameters['geometries'], 'geojson');
          expect(request.url.queryParameters['overview'], 'full');
          return _jsonResponse({
            'routes': [
              {
                'geometry': {
                  'coordinates': [
                    [126.7, 37.3],
                    [126.72, 37.31],
                    [126.78, 37.38],
                    [126.8, 37.4],
                    [126.9, 37.5],
                    [126.81, 37.41],
                  ],
                },
              },
            ],
          });
        }
        if (request.url.path.endsWith('/areaBasedList2')) {
          expect(request.url.queryParameters['areaCode'], '31');
          expect(request.url.queryParameters['contentTypeId'], '12');
          expect(request.url.queryParameters['numOfRows'], '100');
          final sigunguCode = request.url.queryParameters['sigunguCode'];
          if (sigunguCode == '14') {
            return _jsonResponse({
              'response': {
                'body': {
                  'totalCount': 1,
                  'items': {
                    'item': [
                      {
                        'contentid': 'abc',
                        'title': 'API 관광지',
                        'addr1': 'API 주소',
                        'addr2': '123번지',
                        'mapx': '126.81',
                        'mapy': '37.41',
                        'firstimage': 'http://example.com/api.jpg',
                      },
                      {
                        'contentid': 'missing-coordinates',
                        'title': '좌표 없는 관광지',
                        'mapx': '',
                        'mapy': '',
                      },
                    ],
                  },
                },
              },
            });
          }
          if (sigunguCode == '15') {
            return _jsonResponse({
              'response': {
                'body': {'totalCount': 0, 'items': ''},
              },
            });
          }
        }
        return http.Response('{}', 404);
      }),
    );

    final data = await repository.loadSampleData();

    expect(data.routes.single.number, '99');
    expect(data.routes.single.destination, '도착지');
    expect(data.routes.single.defaultDirection.shape, [
      const LatLng(37.3, 126.7),
      const LatLng(37.31, 126.72),
      const LatLng(37.38, 126.78),
      const LatLng(37.4, 126.8),
      const LatLng(37.5, 126.9),
    ]);
    expect(data.routes.single.defaultDirection.stopIds, [
      'odsay_stop_11',
      'odsay_stop_12',
      'odsay_stop_13',
    ]);
    expect(data.routes.single.directions.last.stopIds, [
      'odsay_stop_13',
      'odsay_stop_14',
    ]);
    expect(data.stops, hasLength(4));
    expect(data.touristSpots.single.name, 'API 관광지');
    expect(data.touristSpots.single.address, 'API 주소 123번지');
    expect(data.touristSpots.single.description, isEmpty);
    expect(
      data.touristSpots.single.heroImageUrl,
      'https://example.com/api.jpg',
    );
    expect(data.touristSpots.single.routeIds, ['odsay_route_123']);
  });

  test('ApiBackedB4yRepository maps GBIS route line as road shape', () async {
    final repository = ApiBackedB4yRepository(
      keys: const ApiKeys(
        odsayApiKey: '',
        gbisApiKey: 'gbis-key',
        tourApiKey: '',
        kakaoMapKey: '',
      ),
      userLocation: const LatLng(37.55, 126.97),
      fallback: const _FallbackRepository(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/getBusStationAroundListv2')) {
          expect(request.url.queryParameters['x'], '126.97');
          expect(request.url.queryParameters['y'], '37.55');
          return _gbisResponse('busStationList', [
            {
              'stationId': 101,
              'stationName': '가까운 정류장',
              'x': 126.97,
              'y': 37.55,
              'distance': 10,
            },
          ]);
        }
        if (request.url.path.endsWith('/getBusStationViaRouteListv2')) {
          return _gbisResponse('busRouteList', [
            {'routeId': 200, 'routeName': '88', 'routeDestName': '도착지'},
          ]);
        }
        if (request.url.path.endsWith('/getBusRouteInfoItemv2')) {
          return _gbisResponse('busRouteInfoItem', {
            'routeId': 200,
            'routeName': '88',
            'startStationName': '출발지',
            'endStationName': '도착지',
          });
        }
        if (request.url.path.endsWith('/getBusRouteStationListv2')) {
          expect(request.url.queryParameters['numOfRows'], '100');
          final pageNo = request.url.queryParameters['pageNo'];
          if (pageNo == '1') {
            return _gbisResponse('busRouteStationList', [
              {
                'stationId': 101,
                'stationName': '첫 정류장',
                'x': 126.7,
                'y': 37.3,
                'stationSeq': 1,
              },
              {
                'stationId': 102,
                'stationName': '둘째 정류장',
                'x': 126.8,
                'y': 37.4,
                'stationSeq': 2,
              },
            ], totalCount: 4);
          }
          if (pageNo == '2') {
            return _gbisResponse('busRouteStationList', [
              {
                'stationId': 103,
                'stationName': '셋째 정류장',
                'x': 126.9,
                'y': 37.5,
                'stationSeq': 3,
                'turnYn': 'Y',
              },
              {
                'stationId': 104,
                'stationName': '넷째 정류장',
                'x': 127.0,
                'y': 37.6,
                'stationSeq': 4,
              },
            ], totalCount: 4);
          }
        }
        if (request.url.path.endsWith('/getBusRouteLineListv2')) {
          expect(request.url.queryParameters['numOfRows'], '100');
          return _gbisResponse('busRouteLineList', [
            {'lineSeq': 2, 'x': 126.75, 'y': 37.35},
            {'lineSeq': 4, 'x': 'Infinity', 'y': 37.36},
            {'lineSeq': 5, 'x': 126.76, 'y': 'NaN'},
            {'lineSeq': 6, 'x': 220, 'y': 37.37},
            {'lineSeq': 1, 'x': 126.7, 'y': 37.3},
            {'lineSeq': 3, 'x': 126.8, 'y': 37.4},
          ]);
        }
        return http.Response('{}', 404);
      }),
    );

    final data = await repository.loadSampleData();

    expect(data.routes.single.id, 'gbis_route_200');
    expect(data.routes.single.number, '88');
    expect(data.stops.map((stop) => stop.name), [
      '첫 정류장',
      '둘째 정류장',
      '셋째 정류장',
      '넷째 정류장',
    ]);
    expect(data.routes.single.defaultDirection.stopIds, [
      'gbis_stop_101',
      'gbis_stop_102',
      'gbis_stop_103',
    ]);
    expect(data.routes.single.directions.last.stopIds, [
      'gbis_stop_103',
      'gbis_stop_104',
    ]);
    expect(data.routes.single.defaultDirection.shape, [
      const LatLng(37.3, 126.7),
      const LatLng(37.35, 126.75),
      const LatLng(37.4, 126.8),
    ]);
  });

  test('regional route search uses ODsay citywide bus lane lookup', () async {
    final repository = ApiBackedB4yRepository(
      keys: const ApiKeys(
        odsayApiKey: 'odsay-key',
        gbisApiKey: '',
        tourApiKey: '',
        kakaoMapKey: '',
      ),
      fallback: const _FallbackRepository(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/searchBusLane')) {
          expect(request.url.queryParameters['busNo'], '3');
          expect(request.url.queryParameters['CID'], '1000');
          expect(request.url.queryParameters['displayCnt'], '100');
          return _jsonResponse({
            'result': {
              'lane': [
                {
                  'busID': 300,
                  'busNo': '33',
                  'type': 11,
                  'busCityName': '수도권',
                  'busStartPoint': '출발지',
                  'busEndPoint': '도착지',
                },
                {
                  'busID': 700,
                  'busNo': '700',
                  'type': 11,
                  'busCityName': '서울',
                  'busStartPoint': '서울역',
                  'busEndPoint': '강남역',
                },
              ],
            },
          });
        }
        if (request.url.path.endsWith('/busLaneDetail')) {
          final busId = request.url.queryParameters['busID'];
          if (busId == '300') {
            return _jsonResponse({
              'result': {
                'busID': 300,
                'busNo': '33',
                'busStartPoint': '출발지',
                'busEndPoint': '도착지',
                'station': [
                  {
                    'idx': 1,
                    'stationID': 31,
                    'stationName': '경유 정류장',
                    'x': 126.78,
                    'y': 37.32,
                  },
                  {
                    'idx': 2,
                    'stationID': 32,
                    'stationName': '도착 정류장',
                    'x': 126.9,
                    'y': 37.4,
                  },
                ],
              },
            });
          }
          if (busId == '700') {
            return _jsonResponse({
              'result': {
                'busID': 700,
                'busNo': '700',
                'busStartPoint': '서울역',
                'busEndPoint': '강남역',
                'station': [
                  {
                    'idx': 1,
                    'stationID': 71,
                    'stationName': '서울역',
                    'x': 126.97,
                    'y': 37.55,
                  },
                  {
                    'idx': 2,
                    'stationID': 72,
                    'stationName': '강남역',
                    'x': 127.03,
                    'y': 37.5,
                  },
                ],
              },
            });
          }
        }
        if (request.url.host == 'router.project-osrm.org') {
          return _jsonResponse({
            'routes': [
              {
                'geometry': {
                  'coordinates': [
                    [126.78, 37.32],
                    [126.9, 37.4],
                  ],
                },
              },
            ],
          });
        }
        return http.Response('{}', 404);
      }),
    );

    final routes = await repository.searchRegionalRoutes('3');

    expect(routes.map((route) => route.id), ['odsay_route_300']);
    expect(routes.single.number, '33');
    expect(routes.single.destination, '도착지');
  });
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

http.Response _gbisResponse(String key, Object value, {int? totalCount}) {
  return _jsonResponse({
    'response': {
      'msgHeader': {
        'resultCode': 0,
        'resultMessage': '정상',
        'totalCount': ?totalCount,
      },
      'msgBody': {key: value},
    },
  });
}

class _FallbackRepository implements B4yRepository {
  const _FallbackRepository();

  @override
  Future<B4ySampleData> loadSampleData() async {
    return B4ySampleData(
      stops: const [
        BusStop(
          id: 'fallback_stop',
          name: '샘플 정류장',
          position: LatLng(37.3, 126.7),
          sequence: 1,
        ),
      ],
      routes: const [],
      routePhotoClusters: const [],
      touristSpots: const [],
      reviews: const [],
      missions: const [],
      galleryPhotos: const [],
    );
  }
}
