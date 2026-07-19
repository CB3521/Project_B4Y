import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/api_keys.dart';
import '../data/location_address.dart';
import '../data/b4y_repository.dart';
import '../data/engagement_repository.dart';
import '../data/gallery_repository.dart';
import '../data/profile_repository.dart';
import '../data/route_cache_repository.dart';
import '../domain/b4y_models.dart';

const _oppositeStopPairingToleranceMeters = 500.0;
const _maxTouristSpotStopDistanceMeters = 2000.0;

class SelectedRouteState {
  const SelectedRouteState({required this.routeId, required this.directionId});

  final String routeId;
  final String directionId;

  SelectedRouteState copyWith({String? routeId, String? directionId}) {
    return SelectedRouteState(
      routeId: routeId ?? this.routeId,
      directionId: directionId ?? this.directionId,
    );
  }
}

class PhotoClusterMarker {
  const PhotoClusterMarker({
    required this.cluster,
    required this.position,
    required this.arrow,
  });

  final RoutePhotoCluster cluster;
  final LatLng position;
  final String arrow;
}

class TouristSpotMarker {
  const TouristSpotMarker({
    required this.spot,
    required this.nearestStop,
    required this.arrow,
    this.mission,
  });

  final TouristSpot spot;
  final BusStop nearestStop;
  final String arrow;
  final Mission? mission;
}

class RouteMapOverlay {
  const RouteMapOverlay({
    required this.route,
    required this.direction,
    required this.stops,
    required this.touristSpotByStopId,
    required this.shape,
    required this.photoMarkers,
    required this.spotMarkers,
  });

  final BusRoute route;
  final RouteDirection direction;
  final List<BusStop> stops;
  final Map<String, TouristSpot> touristSpotByStopId;
  final List<LatLng> shape;
  final List<PhotoClusterMarker> photoMarkers;
  final List<TouristSpotMarker> spotMarkers;
}

class SpotRoutePlan {
  const SpotRoutePlan({
    required this.overlay,
    required this.visibleStops,
    required this.boardingStop,
    required this.alightingStop,
    required this.hasSelectedLocation,
    required this.legs,
  });

  final RouteMapOverlay overlay;
  final List<BusStop> visibleStops;
  final BusStop boardingStop;
  final BusStop alightingStop;
  final bool hasSelectedLocation;
  final List<SpotRouteLeg> legs;

  bool get hasTransfer => legs.length > 1;

  int get transferCount => legs.length <= 1 ? 0 : legs.length - 1;

  int get stopCount =>
      legs.fold<int>(0, (total, leg) => total + leg.visibleStops.length);
}

class SpotRouteLeg {
  const SpotRouteLeg({
    required this.overlay,
    required this.visibleStops,
    required this.boardingStop,
    required this.alightingStop,
  });

  final RouteMapOverlay overlay;
  final List<BusStop> visibleStops;
  final BusStop boardingStop;
  final BusStop alightingStop;
}

final apiKeysProvider = FutureProvider<ApiKeys>((ref) {
  return ApiKeys.load();
});

final currentLocationProvider = FutureProvider<LatLng?>((ref) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180) {
      return null;
    }
    return LatLng(position.latitude, position.longitude);
  } on Object {
    return null;
  }
});

final mapSearchCenterProvider = StateProvider<LatLng?>((ref) => null);

final pendingMapCenterProvider = StateProvider<LatLng?>((ref) => null);

final locationAddressProvider = FutureProvider.family<String?, LatLng>((
  ref,
  location,
) async {
  try {
    return await reverseGeocodeShortAddress(location);
  } on Object {
    return null;
  }
});

final b4yRepositoryProvider = Provider<B4yRepository>((ref) {
  final keys = ref.watch(apiKeysProvider).valueOrNull ?? ApiKeys.empty;
  final userLocation = ref.watch(currentLocationProvider).valueOrNull;
  final searchCenter = ref.watch(mapSearchCenterProvider) ?? userLocation;
  return ApiBackedB4yRepository(keys: keys, userLocation: searchCenter);
});

final b4yDataProvider = FutureProvider<B4ySampleData>((ref) async {
  await ref.watch(apiKeysProvider.future);
  return ref.watch(b4yRepositoryProvider).loadSampleData();
});

final selectedRouteProvider = StateProvider<SelectedRouteState?>((ref) {
  return null;
});

enum HomeContentMode { tourist, photos, missions }

final homeContentModeProvider = StateProvider<HomeContentMode>((ref) {
  return HomeContentMode.tourist;
});

final selectedDirectionIdProvider = StateProvider<String?>((ref) => null);

final routeMapOverlayProvider = Provider<RouteMapOverlay?>((ref) {
  final overlays = ref.watch(routeMapOverlaysProvider);
  return overlays.firstOrNull;
});

final routeMapOverlaysProvider = Provider<List<RouteMapOverlay>>((ref) {
  final data = ref.watch(b4yDataProvider).valueOrNull;
  final selection = ref.watch(selectedRouteProvider);
  if (data == null || data.routes.isEmpty) {
    return const [];
  }

  if (selection != null) {
    final route = data.routeById(selection.routeId);
    final direction = route.directionById(selection.directionId);
    return [buildRouteMapOverlay(data, route, direction)];
  }

  return [
    for (final route in data.routes)
      buildRouteMapOverlay(data, route, route.defaultDirection),
  ];
});

final spotRoutePlanProvider = Provider.family<SpotRoutePlan?, String>((
  ref,
  spotId,
) {
  final data = ref.watch(b4yDataProvider).valueOrNull;
  final selectedLocation = ref.watch(mapSearchCenterProvider);
  final currentLocation = ref.watch(currentLocationProvider).valueOrNull;
  final originLocation = selectedLocation ?? currentLocation;
  if (data == null || data.routes.isEmpty) {
    return null;
  }

  final spot = data.spotById(spotId);
  final candidateRoutes = spot.routeIds
      .map((routeId) => _routeByIdOrNull(data, routeId))
      .whereType<BusRoute>()
      .toList();
  final routes = candidateRoutes.isEmpty ? data.routes : candidateRoutes;

  final candidates = <_SpotRouteCandidate>[];
  for (final route in routes) {
    if (!route.directions.any(
      (direction) => direction.stopIds.contains(spot.nearestStopId),
    )) {
      continue;
    }
    final routeStops = route.directions
        .expand((direction) => direction.stopIds)
        .toSet()
        .map(data.stopById)
        .where((stop) => isValidMapPoint(stop.position))
        .toList();
    if (routeStops.isEmpty) {
      continue;
    }
    const distance = Distance();
    final routeSpotDistance = routeStops
        .map((stop) => distance(spot.position, stop.position))
        .reduce((a, b) => a < b ? a : b);

    for (final direction in route.directions) {
      final stops = direction.stopIds
          .map(data.stopById)
          .where((stop) => isValidMapPoint(stop.position))
          .toList();
      if (stops.isEmpty) {
        continue;
      }

      final alightingIndex = originLocation == null
          ? stops.indexWhere((stop) => stop.id == spot.nearestStopId)
          : nearestStopIndex(spot.position, stops);
      if (alightingIndex < 0) {
        continue;
      }
      final alightingDistance = distance(
        spot.position,
        stops[alightingIndex].position,
      );
      if (originLocation != null &&
          alightingDistance >
              routeSpotDistance + _oppositeStopPairingToleranceMeters) {
        continue;
      }
      final boardingIndex = originLocation == null
          ? 0
          : nearestStopIndex(originLocation, stops);
      final candidate = _SpotRouteCandidate(
        route: route,
        direction: direction,
        stops: stops,
        boardingIndex: boardingIndex,
        alightingIndex: alightingIndex,
        boardingDistance: originLocation == null
            ? 0
            : distance(originLocation, stops[boardingIndex].position),
        alightingDistance: alightingDistance,
      );
      candidates.add(candidate);
    }
  }

  if (originLocation == null) {
    final candidate = candidates.firstOrNull;
    if (candidate == null) {
      return null;
    }
    return _spotRoutePlanFromCandidate(
      data,
      candidate,
      hasSelectedLocation: false,
    );
  }

  final travelableCandidates = candidates.where((candidate) {
    return candidate.isTravelable;
  }).toList();
  travelableCandidates.sort((a, b) {
    final stopCountComparison = a.segmentStopCount.compareTo(
      b.segmentStopCount,
    );
    if (stopCountComparison != 0) {
      return stopCountComparison;
    }
    final boardingDistanceComparison = a.boardingDistance.compareTo(
      b.boardingDistance,
    );
    if (boardingDistanceComparison != 0) {
      return boardingDistanceComparison;
    }
    return a.alightingDistance.compareTo(b.alightingDistance);
  });

  final transferCandidates = _spotTransferRouteCandidates(
    data: data,
    spot: spot,
    spotRoutes: routes,
    originLocation: originLocation,
  );
  transferCandidates.sort((a, b) {
    final stopCountComparison = a.stopCount.compareTo(b.stopCount);
    if (stopCountComparison != 0) {
      return stopCountComparison;
    }
    final boardingDistanceComparison = a.boardingDistance.compareTo(
      b.boardingDistance,
    );
    if (boardingDistanceComparison != 0) {
      return boardingDistanceComparison;
    }
    return a.alightingDistance.compareTo(b.alightingDistance);
  });

  final directCandidate = travelableCandidates.firstOrNull;
  final transferCandidate = transferCandidates.firstOrNull;
  if (directCandidate == null && transferCandidate == null) {
    return null;
  }
  if (directCandidate == null) {
    return _spotRoutePlanFromTransferCandidate(
      data,
      transferCandidate!,
      hasSelectedLocation: true,
    );
  }
  return _spotRoutePlanFromCandidate(
    data,
    directCandidate,
    hasSelectedLocation: true,
  );
});

final _routeOverlayCache = Expando<Map<String, RouteMapOverlay>>();

RouteMapOverlay buildRouteMapOverlay(
  B4ySampleData data,
  BusRoute route,
  RouteDirection direction,
) {
  var cache = _routeOverlayCache[data];
  if (cache == null) {
    cache = <String, RouteMapOverlay>{};
    _routeOverlayCache[data] = cache;
  }
  final key = '${route.id}:${direction.id}';
  return cache.putIfAbsent(
    key,
    () => _buildRouteMapOverlay(data, route, direction),
  );
}

RouteMapOverlay _buildRouteMapOverlay(
  B4ySampleData data,
  BusRoute route,
  RouteDirection direction,
) {
  final stops = direction.stopIds
      .map(data.stopById)
      .where((stop) => isValidMapPoint(stop.position))
      .toList();
  final shape = direction.shape.where(isValidMapPoint).toList();
  final touristSpotByStopId = {
    for (final spot in data.touristSpots)
      if (spot.routeIds.contains(route.id) &&
          direction.stopIds.contains(spot.nearestStopId) &&
          isValidMapPoint(spot.position) &&
          _isSpotNearStop(data, spot))
        spot.nearestStopId: spot,
  };
  final photoMarkers = data.routePhotoClusters
      .where(
        (cluster) =>
            cluster.routeId == route.id && cluster.directionId == direction.id,
      )
      .map((cluster) {
        final start = data.stopById(cluster.startStopId).position;
        final end = data.stopById(cluster.endStopId).position;
        if (!isValidMapPoint(start) || !isValidMapPoint(end)) {
          return null;
        }
        return PhotoClusterMarker(
          cluster: cluster,
          position: midpoint(start, end),
          arrow: arrowForSegment(start, end),
        );
      })
      .whereType<PhotoClusterMarker>()
      .toList();
  final spotMarkers = data.touristSpots
      .where((spot) => spot.routeIds.contains(route.id))
      .where((spot) => direction.stopIds.contains(spot.nearestStopId))
      .map((spot) {
        final nearestStop = data.stopById(spot.nearestStopId);
        if (!isValidMapPoint(nearestStop.position) ||
            !isValidMapPoint(spot.position) ||
            !_isSpotNearStop(data, spot)) {
          return null;
        }
        return TouristSpotMarker(
          spot: spot,
          nearestStop: nearestStop,
          arrow: arrowForSegment(nearestStop.position, spot.position),
          mission: topMissionForSpot(data.missions, spot.id),
        );
      })
      .whereType<TouristSpotMarker>()
      .toList();

  return RouteMapOverlay(
    route: route,
    direction: direction,
    stops: stops,
    touristSpotByStopId: touristSpotByStopId,
    shape: shape,
    photoMarkers: photoMarkers,
    spotMarkers: spotMarkers,
  );
}

bool _isSpotNearStop(B4ySampleData data, TouristSpot spot) {
  final nearestStop = data.stopById(spot.nearestStopId);
  if (!isValidMapPoint(nearestStop.position) ||
      !isValidMapPoint(spot.position)) {
    return false;
  }
  const distance = Distance();
  return distance(nearestStop.position, spot.position) <=
      _maxTouristSpotStopDistanceMeters;
}

final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  try {
    return FirebaseAuth.instance;
  } on Object {
    return null;
  }
});

final authUserProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth?.authStateChanges() ?? Stream.value(null);
});

final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  try {
    return FirestoreProfileRepository(FirebaseFirestore.instance);
  } on FirebaseException {
    return null;
  }
});

final currentProfileProvider = StreamProvider<UserProfile?>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final user = ref.watch(authUserProvider).valueOrNull;
  if (repository == null || user == null || user.isAnonymous) {
    return Stream.value(null);
  }
  return repository.watchProfile(user.uid);
});

final engagementRepositoryProvider = Provider<EngagementRepository?>((ref) {
  try {
    return FirestoreEngagementRepository(FirebaseFirestore.instance);
  } on Object {
    return null;
  }
});

final reviewsForSpotProvider = StreamProvider.autoDispose
    .family<List<Review>, String>((ref, spotId) {
      final repository = ref.watch(engagementRepositoryProvider);
      final userId = ref.watch(authUserProvider).valueOrNull?.uid ?? '';
      return repository?.watchReviews(spotId, userId) ??
          Stream.value(const <Review>[]);
    });

final myReviewsProvider = StreamProvider<List<Review>>((ref) {
  final repository = ref.watch(engagementRepositoryProvider);
  final user = ref.watch(authUserProvider).valueOrNull;
  final userId = user?.uid ?? '';
  if (repository == null || user == null || user.isAnonymous) {
    return Stream.value(const <Review>[]);
  }
  return repository.watchReviewsByAuthor(user.uid, userId);
});

final missionsForSpotProvider = StreamProvider.autoDispose
    .family<List<Mission>, String>((ref, spotId) {
      final repository = ref.watch(engagementRepositoryProvider);
      final userId = ref.watch(authUserProvider).valueOrNull?.uid ?? '';
      return repository?.watchMissions(spotId, userId) ??
          Stream.value(const <Mission>[]);
    });

final missionsForRouteProvider = StreamProvider.autoDispose
    .family<List<Mission>, String>((ref, routeId) {
      final repository = ref.watch(engagementRepositoryProvider);
      final userId = ref.watch(authUserProvider).valueOrNull?.uid ?? '';
      return repository?.watchMissionsForRoute(routeId, userId) ??
          Stream.value(const <Mission>[]);
    });

final homeMissionsProvider = StreamProvider.autoDispose
    .family<List<Mission>, String?>((ref, routeId) {
      final repository = ref.watch(engagementRepositoryProvider);
      final userId = ref.watch(authUserProvider).valueOrNull?.uid ?? '';
      if (repository != null) {
        return repository.watchAllMissions(userId);
      }
      final data = ref.watch(b4yDataProvider).valueOrNull;
      return Stream.value(data?.missions ?? const <Mission>[]);
    });

final routeCacheRepositoryProvider = Provider<RouteCacheRepository?>((ref) {
  try {
    return FirestoreRouteCacheRepository(FirebaseFirestore.instance);
  } on Object {
    return null;
  }
});

final regionalRouteSearchProvider =
    FutureProvider.family<List<BusRoute>, String>((ref, query) async {
      final normalizedQuery = normalizeRouteCacheQuery(query);
      if (normalizedQuery.isEmpty) {
        return const <BusRoute>[];
      }

      final cacheRepository = ref.watch(routeCacheRepositoryProvider);
      var cachedRoutes = const <BusRoute>[];
      try {
        cachedRoutes =
            await cacheRepository?.searchRoutes(normalizedQuery) ??
            const <BusRoute>[];
      } on Object {
        cachedRoutes = const <BusRoute>[];
      }
      if (cachedRoutes.isNotEmpty) {
        return cachedRoutes;
      }

      final keys = await ref.watch(apiKeysProvider.future);
      final data = ref.watch(b4yDataProvider).valueOrNull;
      final routes = await ApiBackedB4yRepository(keys: keys)
          .searchRegionalRoutes(
            normalizedQuery,
            fallbackRoutes: data?.routes ?? const [],
          );
      if (routes.isNotEmpty) {
        try {
          await cacheRepository?.cacheRoutes(routes);
        } on Object {
          // Route search should still work even when Firestore cache is offline.
        }
      }
      return routes;
    });

final myMissionsProvider = StreamProvider<List<Mission>>((ref) {
  final repository = ref.watch(engagementRepositoryProvider);
  final user = ref.watch(authUserProvider).valueOrNull;
  final userId = user?.uid ?? '';
  if (repository == null || user == null || user.isAnonymous) {
    return Stream.value(const <Mission>[]);
  }
  return repository.watchMissionsByAuthor(user.uid, userId);
});

final galleryRepositoryProvider = Provider<GalleryRepository?>((ref) {
  try {
    return FirestoreGalleryRepository(FirebaseFirestore.instance);
  } on Object {
    return null;
  }
});

final galleryForSpotProvider = StreamProvider.autoDispose
    .family<List<GalleryPhoto>, String>((ref, spotId) {
      final repository = ref.watch(galleryRepositoryProvider);
      final userId = ref.watch(authUserProvider).valueOrNull?.uid ?? '';
      if (repository != null) {
        return repository.watchPhotos(
          targetType: 'spot',
          targetId: spotId,
          userId: userId,
        );
      }
      final data = ref.watch(b4yDataProvider).valueOrNull;
      return Stream.value(
        data?.galleryPhotos.where((photo) => photo.spotId == spotId).toList() ??
            const <GalleryPhoto>[],
      );
    });

final galleryForRouteProvider = StreamProvider.autoDispose
    .family<List<GalleryPhoto>, String>((ref, routeId) {
      final repository = ref.watch(galleryRepositoryProvider);
      final userId = ref.watch(authUserProvider).valueOrNull?.uid ?? '';
      if (repository != null) {
        return repository.watchPhotos(
          targetType: 'route',
          targetId: routeId,
          userId: userId,
        );
      }
      final data = ref.watch(b4yDataProvider).valueOrNull;
      return Stream.value(
        data?.galleryPhotos
                .where((photo) => photo.routeId == routeId)
                .toList() ??
            const <GalleryPhoto>[],
      );
    });

final homeGalleryPhotosProvider = StreamProvider.autoDispose
    .family<List<GalleryPhoto>, String?>((ref, routeId) {
      final repository = ref.watch(galleryRepositoryProvider);
      final userId = ref.watch(authUserProvider).valueOrNull?.uid ?? '';
      if (repository != null && routeId != null) {
        return repository.watchPhotos(
          targetType: 'route',
          targetId: routeId,
          userId: userId,
        );
      }
      final data = ref.watch(b4yDataProvider).valueOrNull;
      return Stream.value(
        routeId == null
            ? const <GalleryPhoto>[]
            : data?.galleryPhotos
                      .where((photo) => photo.routeId == routeId)
                      .toList() ??
                  const <GalleryPhoto>[],
      );
    });

List<GalleryPhoto> sortedGalleryPhotos(
  List<GalleryPhoto> photos,
  GallerySort sort, {
  int limit = 5,
}) {
  return sortGalleryPhotos(photos, sort, limit: limit);
}

Mission? topMissionForSpot(List<Mission> missions, String spotId) {
  final spotMissions = missions
      .where((mission) => mission.spotId == spotId)
      .toList();
  if (spotMissions.isEmpty) {
    return null;
  }
  return topRepresentativeMission(spotMissions);
}

LatLng midpoint(LatLng a, LatLng b) {
  return LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
}

int nearestStopIndex(LatLng position, List<BusStop> stops) {
  if (stops.isEmpty) {
    return -1;
  }
  const distance = Distance();
  var nearestIndex = 0;
  var nearestDistance = distance(position, stops.first.position);
  for (var index = 1; index < stops.length; index++) {
    final nextDistance = distance(position, stops[index].position);
    if (nextDistance < nearestDistance) {
      nearestDistance = nextDistance;
      nearestIndex = index;
    }
  }
  return nearestIndex;
}

String arrowForSegment(LatLng from, LatLng to) {
  final latDelta = to.latitude - from.latitude;
  final lngDelta = to.longitude - from.longitude;
  if (latDelta.abs() > lngDelta.abs()) {
    return latDelta >= 0 ? '^' : 'V';
  }
  return lngDelta >= 0 ? '>' : '<';
}

bool isValidMapPoint(LatLng point) {
  return point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude >= -90 &&
      point.latitude <= 90 &&
      point.longitude >= -180 &&
      point.longitude <= 180;
}

BusRoute? _routeByIdOrNull(B4ySampleData data, String routeId) {
  for (final route in data.routes) {
    if (route.id == routeId) {
      return route;
    }
  }
  return null;
}

SpotRoutePlan _spotRoutePlanFromCandidate(
  B4ySampleData data,
  _SpotRouteCandidate candidate, {
  required bool hasSelectedLocation,
}) {
  final leg = _spotRouteLegFromCandidate(data, candidate);
  return SpotRoutePlan(
    overlay: leg.overlay,
    visibleStops: leg.visibleStops,
    boardingStop: leg.boardingStop,
    alightingStop: leg.alightingStop,
    hasSelectedLocation: hasSelectedLocation,
    legs: [leg],
  );
}

SpotRoutePlan _spotRoutePlanFromTransferCandidate(
  B4ySampleData data,
  _SpotTransferRouteCandidate candidate, {
  required bool hasSelectedLocation,
}) {
  final legs = [
    _spotRouteLegFromCandidate(data, candidate.firstLeg),
    _spotRouteLegFromCandidate(data, candidate.secondLeg),
  ];
  final visibleStops = <BusStop>[
    ...legs.first.visibleStops,
    ...legs.last.visibleStops.skip(1),
  ];
  return SpotRoutePlan(
    overlay: legs.last.overlay,
    visibleStops: visibleStops,
    boardingStop: legs.first.boardingStop,
    alightingStop: legs.last.alightingStop,
    hasSelectedLocation: hasSelectedLocation,
    legs: legs,
  );
}

SpotRouteLeg _spotRouteLegFromCandidate(
  B4ySampleData data,
  _SpotRouteCandidate candidate,
) {
  final overlay = buildRouteMapOverlay(
    data,
    candidate.route,
    candidate.direction,
  );
  final start = candidate.boardingIndex;
  final end = candidate.alightingIndex;
  final visibleStops = start <= end
      ? candidate.stops.sublist(start, end + 1)
      : candidate.stops.sublist(end, start + 1).reversed.toList();
  return SpotRouteLeg(
    overlay: overlay,
    visibleStops: visibleStops,
    boardingStop: candidate.stops[start],
    alightingStop: candidate.stops[end],
  );
}

List<_SpotTransferRouteCandidate> _spotTransferRouteCandidates({
  required B4ySampleData data,
  required TouristSpot spot,
  required List<BusRoute> spotRoutes,
  required LatLng originLocation,
}) {
  const distance = Distance();
  final candidates = <_SpotTransferRouteCandidate>[];

  for (final secondRoute in spotRoutes) {
    for (final secondDirection in secondRoute.directions) {
      final secondStops = secondDirection.stopIds
          .map(data.stopById)
          .where((stop) => isValidMapPoint(stop.position))
          .toList();
      if (secondStops.isEmpty) {
        continue;
      }
      final alightingIndex = nearestStopIndex(spot.position, secondStops);
      if (alightingIndex < 0) {
        continue;
      }
      final secondStopIds = secondStops
          .take(alightingIndex + 1)
          .map((stop) => stop.id)
          .toSet();

      for (final firstRoute in data.routes) {
        for (final firstDirection in firstRoute.directions) {
          if (firstRoute.id == secondRoute.id &&
              firstDirection.id == secondDirection.id) {
            continue;
          }
          final firstStops = firstDirection.stopIds
              .map(data.stopById)
              .where((stop) => isValidMapPoint(stop.position))
              .toList();
          if (firstStops.isEmpty) {
            continue;
          }
          final boardingIndex = nearestStopIndex(originLocation, firstStops);
          if (boardingIndex < 0) {
            continue;
          }
          for (
            var transferIndex = boardingIndex;
            transferIndex < firstStops.length;
            transferIndex++
          ) {
            final transferStop = firstStops[transferIndex];
            if (!secondStopIds.contains(transferStop.id)) {
              continue;
            }
            final secondBoardingIndex = secondStops.indexWhere(
              (stop) => stop.id == transferStop.id,
            );
            if (secondBoardingIndex < 0 ||
                secondBoardingIndex > alightingIndex) {
              continue;
            }
            final firstLeg = _SpotRouteCandidate(
              route: firstRoute,
              direction: firstDirection,
              stops: firstStops,
              boardingIndex: boardingIndex,
              alightingIndex: transferIndex,
              boardingDistance: distance(
                originLocation,
                firstStops[boardingIndex].position,
              ),
              alightingDistance: 0,
            );
            final secondLeg = _SpotRouteCandidate(
              route: secondRoute,
              direction: secondDirection,
              stops: secondStops,
              boardingIndex: secondBoardingIndex,
              alightingIndex: alightingIndex,
              boardingDistance: 0,
              alightingDistance: distance(
                spot.position,
                secondStops[alightingIndex].position,
              ),
            );
            candidates.add(
              _SpotTransferRouteCandidate(
                firstLeg: firstLeg,
                secondLeg: secondLeg,
                boardingDistance: firstLeg.boardingDistance,
                alightingDistance: secondLeg.alightingDistance,
              ),
            );
          }
        }
      }
    }
  }

  return candidates;
}

class _SpotRouteCandidate {
  const _SpotRouteCandidate({
    required this.route,
    required this.direction,
    required this.stops,
    required this.boardingIndex,
    required this.alightingIndex,
    required this.boardingDistance,
    required this.alightingDistance,
  });

  final BusRoute route;
  final RouteDirection direction;
  final List<BusStop> stops;
  final int boardingIndex;
  final int alightingIndex;
  final double boardingDistance;
  final double alightingDistance;

  bool get isTravelable => boardingIndex <= alightingIndex;

  int get segmentStopCount => (alightingIndex - boardingIndex).abs() + 1;
}

class _SpotTransferRouteCandidate {
  const _SpotTransferRouteCandidate({
    required this.firstLeg,
    required this.secondLeg,
    required this.boardingDistance,
    required this.alightingDistance,
  });

  final _SpotRouteCandidate firstLeg;
  final _SpotRouteCandidate secondLeg;
  final double boardingDistance;
  final double alightingDistance;

  int get stopCount => firstLeg.segmentStopCount + secondLeg.segmentStopCount;
}
