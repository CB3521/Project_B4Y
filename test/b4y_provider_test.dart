import 'package:b4y/src/application/b4y_providers.dart';
import 'package:b4y/src/config/api_keys.dart';
import 'package:b4y/src/data/b4y_repository.dart';
import 'package:b4y/src/domain/b4y_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('selected route overlay exposes direction shape and stops', () async {
    final container = _containerWithData(_sampleData());
    addTearDown(container.dispose);

    await container.read(b4yDataProvider.future);
    container.read(selectedRouteProvider.notifier).state =
        const SelectedRouteState(routeId: 'route_1', directionId: 'down');

    final overlay = container.read(routeMapOverlayProvider);

    expect(overlay, isNotNull);
    expect(overlay!.route.number, '10');
    expect(overlay.direction.id, 'down');
    expect(overlay.shape.first, const LatLng(37.2, 126.2));
    expect(overlay.stops.map((stop) => stop.id), [
      'stop_b',
      'stop_mid',
      'stop_a',
    ]);
  });

  test(
    'photo cluster marker is placed at the midpoint between two stops',
    () async {
      final container = _containerWithData(_sampleData());
      addTearDown(container.dispose);

      await container.read(b4yDataProvider.future);
      final overlay = container.read(routeMapOverlayProvider);
      final marker = overlay!.photoMarkers.single;

      expect(marker.position.latitude, 37.1);
      expect(marker.position.longitude, 126.1);
    },
  );

  test('tourist spot marker uses nearestStopId', () async {
    final container = _containerWithData(_sampleData());
    addTearDown(container.dispose);

    await container.read(b4yDataProvider.future);
    final overlay = container.read(routeMapOverlayProvider);
    final marker = overlay!.spotMarkers.single;

    expect(marker.nearestStop.id, 'stop_b');
  });

  test(
    'route overlay links nearby tourist spots to their stop markers',
    () async {
      final container = _containerWithData(_sampleData());
      addTearDown(container.dispose);

      await container.read(b4yDataProvider.future);
      final overlay = container.read(routeMapOverlayProvider);

      expect(overlay!.touristSpotByStopId['stop_b']!.id, 'spot_1');
      expect(overlay.touristSpotByStopId.containsKey('stop_a'), isFalse);
    },
  );

  test(
    'route overlay hides tourist spots farther than 2km from stop',
    () async {
      final container = _containerWithData(_sampleDataWithDistantTouristSpot());
      addTearDown(container.dispose);

      await container.read(b4yDataProvider.future);
      final overlay = container.read(routeMapOverlayProvider);

      expect(overlay!.touristSpotByStopId.containsKey('stop_b'), isFalse);
      expect(overlay.spotMarkers, isEmpty);
    },
  );

  test(
    'spot route plan starts from the stop nearest the selected location',
    () async {
      final container = _containerWithData(
        _sampleData(),
        currentLocation: const LatLng(37.19, 126.19),
        selectedLocation: const LatLng(37.01, 126.01),
      );
      addTearDown(container.dispose);

      await container.read(b4yDataProvider.future);
      await container.read(currentLocationProvider.future);
      final plan = container.read(spotRoutePlanProvider('spot_1'));

      expect(plan, isNotNull);
      expect(plan!.overlay.route.id, 'route_1');
      expect(plan.visibleStops.map((stop) => stop.id), [
        'stop_a',
        'stop_mid',
        'stop_b',
      ]);
      expect(plan.boardingStop.id, 'stop_a');
      expect(plan.alightingStop.id, 'stop_b');
      expect(plan.hasSelectedLocation, isTrue);
    },
  );

  test('spot route plan uses current location as its origin', () async {
    final container = _containerWithData(
      _sampleData(),
      currentLocation: const LatLng(37.11, 126.11),
    );
    addTearDown(container.dispose);

    await container.read(b4yDataProvider.future);
    await container.read(currentLocationProvider.future);
    final plan = container.read(spotRoutePlanProvider('spot_1'));

    expect(plan, isNotNull);
    expect(plan!.boardingStop.id, 'stop_mid');
    expect(plan.visibleStops.map((stop) => stop.id), ['stop_mid', 'stop_b']);
    expect(plan.hasSelectedLocation, isTrue);
  });

  test('spot route plan chooses the direction with fewer stops', () async {
    final container = _containerWithData(
      _sampleDataWithShorterDownDirection(),
      selectedLocation: const LatLng(37.01, 126.01),
    );
    addTearDown(container.dispose);

    await container.read(b4yDataProvider.future);
    await container.read(currentLocationProvider.future);
    final plan = container.read(spotRoutePlanProvider('spot_1'));

    expect(plan, isNotNull);
    expect(plan!.overlay.direction.id, 'down');
    expect(plan.visibleStops.map((stop) => stop.id), ['stop_a', 'stop_b']);
  });

  test(
    'spot route plan compares the nearest and opposite boarding stops',
    () async {
      final container = _containerWithData(
        _sampleDataWithOppositeStopShortcut(),
        selectedLocation: const LatLng(37, 126),
      );
      addTearDown(container.dispose);

      await container.read(b4yDataProvider.future);
      await container.read(currentLocationProvider.future);
      final plan = container.read(spotRoutePlanProvider('spot_1'));

      expect(plan, isNotNull);
      expect(plan!.overlay.direction.id, 'down');
      expect(plan.boardingStop.id, 'down_current');
      expect(plan.alightingStop.id, 'down_spot');
      expect(plan.visibleStops.map((stop) => stop.id), [
        'down_current',
        'down_spot',
      ]);
    },
  );

  test(
    'spot route plan can use a transfer route to reach the tourist spot',
    () async {
      final container = _containerWithData(
        _sampleDataWithTransferRoute(),
        selectedLocation: const LatLng(37, 126),
      );
      addTearDown(container.dispose);

      await container.read(b4yDataProvider.future);
      await container.read(currentLocationProvider.future);
      final plan = container.read(spotRoutePlanProvider('spot_1'));

      expect(plan, isNotNull);
      expect(plan!.hasTransfer, isTrue);
      expect(plan.transferCount, 1);
      expect(plan.legs.map((leg) => leg.overlay.route.id), [
        'route_origin',
        'route_spot',
      ]);
      expect(plan.boardingStop.id, 'origin_stop');
      expect(plan.alightingStop.id, 'spot_stop');
      expect(plan.visibleStops.map((stop) => stop.id), [
        'origin_stop',
        'transfer_stop',
        'spot_stop',
      ]);
    },
  );

  test(
    'spot route plan prefers a direct route over a shorter transfer route',
    () async {
      final container = _containerWithData(
        _sampleDataWithDirectAndShorterTransferRoute(),
        selectedLocation: const LatLng(37, 126),
      );
      addTearDown(container.dispose);

      await container.read(b4yDataProvider.future);
      await container.read(currentLocationProvider.future);
      final plan = container.read(spotRoutePlanProvider('spot_1'));

      expect(plan, isNotNull);
      expect(plan!.hasTransfer, isFalse);
      expect(plan.transferCount, 0);
      expect(plan.overlay.route.id, 'route_direct');
      expect(plan.boardingStop.id, 'origin_stop');
      expect(plan.alightingStop.id, 'spot_stop');
      expect(plan.visibleStops.map((stop) => stop.id), [
        'origin_stop',
        'direct_mid_1',
        'direct_mid_2',
        'direct_mid_3',
        'spot_stop',
      ]);
    },
  );

  test('tourist spot marker exposes the top mission when available', () async {
    final container = _containerWithData(_sampleData());
    addTearDown(container.dispose);

    await container.read(b4yDataProvider.future);
    final overlay = container.read(routeMapOverlayProvider);
    final marker = overlay!.spotMarkers.single;

    expect(marker.mission, isNotNull);
    expect(marker.mission!.id, 'mission_2');
  });

  test(
    'map search center overrides current location for route loading',
    () async {
      const currentLocation = LatLng(37.1, 126.1);
      const selectedMapCenter = LatLng(37.4, 126.4);
      final container = ProviderContainer(
        overrides: [
          apiKeysProvider.overrideWith((ref) async => ApiKeys.empty),
          currentLocationProvider.overrideWith((ref) async => currentLocation),
        ],
      );
      addTearDown(container.dispose);

      await container.read(apiKeysProvider.future);
      await container.read(currentLocationProvider.future);
      expect(
        (container.read(b4yRepositoryProvider) as ApiBackedB4yRepository)
            .userLocation,
        currentLocation,
      );

      container.read(mapSearchCenterProvider.notifier).state =
          selectedMapCenter;

      expect(
        (container.read(b4yRepositoryProvider) as ApiBackedB4yRepository)
            .userLocation,
        selectedMapCenter,
      );
    },
  );

  test('gallery sorting limits to five items', () {
    final photos = List.generate(
      7,
      (index) => GalleryPhoto(
        id: 'photo_$index',
        spotId: 'spot_1',
        imageUrl: 'https://example.com/$index.jpg',
        authorNickname: 'user_$index',
        description: '',
        createdAt: DateTime.utc(2026, 6, index + 1),
        likeCount: index,
        distanceMeters: 700 - index,
      ),
    );

    final popular = sortedGalleryPhotos(photos, GallerySort.popular);
    final latest = sortedGalleryPhotos(photos, GallerySort.latest);
    final distance = sortedGalleryPhotos(photos, GallerySort.distance);

    expect(popular, hasLength(5));
    expect(popular.first.id, 'photo_6');
    expect(latest.first.id, 'photo_6');
    expect(distance.first.id, 'photo_6');
  });
}

ProviderContainer _containerWithData(
  B4ySampleData data, {
  LatLng? currentLocation,
  LatLng? selectedLocation,
}) {
  final container = ProviderContainer(
    overrides: [
      b4yRepositoryProvider.overrideWithValue(_FakeB4yRepository(data)),
      if (currentLocation != null)
        currentLocationProvider.overrideWith((ref) async => currentLocation),
    ],
  );
  if (selectedLocation != null) {
    container.read(mapSearchCenterProvider.notifier).state = selectedLocation;
  }
  return container;
}

class _FakeB4yRepository implements B4yRepository {
  const _FakeB4yRepository(this.data);

  final B4ySampleData data;

  @override
  Future<B4ySampleData> loadSampleData() async => data;
}

B4ySampleData _sampleData() {
  final stops = [
    const BusStop(
      id: 'stop_a',
      name: 'A 정류장',
      position: LatLng(37, 126),
      sequence: 1,
    ),
    const BusStop(
      id: 'stop_mid',
      name: '중간 정류장',
      position: LatLng(37.1, 126.1),
      sequence: 2,
    ),
    const BusStop(
      id: 'stop_b',
      name: 'B 정류장',
      position: LatLng(37.2, 126.2),
      sequence: 3,
    ),
  ];
  final route = BusRoute(
    id: 'route_1',
    number: '10',
    destination: 'B 정류장',
    directions: const [
      RouteDirection(
        id: 'up',
        name: '상행',
        destination: 'B 방면',
        stopIds: ['stop_a', 'stop_mid', 'stop_b'],
        shape: [LatLng(37, 126), LatLng(37.1, 126.1), LatLng(37.2, 126.2)],
      ),
      RouteDirection(
        id: 'down',
        name: '하행',
        destination: 'A 방면',
        stopIds: ['stop_b', 'stop_mid', 'stop_a'],
        shape: [LatLng(37.2, 126.2), LatLng(37.1, 126.1), LatLng(37, 126)],
      ),
    ],
  );
  return B4ySampleData(
    stops: stops,
    routes: [route],
    routePhotoClusters: [
      RoutePhotoCluster(
        id: 'cluster_1',
        routeId: 'route_1',
        directionId: 'up',
        startStopId: 'stop_a',
        endStopId: 'stop_b',
        photos: [
          B4yPhoto(
            id: 'photo_1',
            imageUrl: 'https://example.com/photo.jpg',
            authorNickname: 'tester',
            description: '샘플',
            createdAt: DateTime.utc(2026),
            likeCount: 1,
            distanceMeters: 10,
          ),
        ],
      ),
    ],
    touristSpots: const [
      TouristSpot(
        id: 'spot_1',
        name: '관광지',
        description: '설명',
        position: LatLng(37.204, 126.204),
        heroImageUrl: 'https://example.com/spot.jpg',
        nearestStopId: 'stop_b',
        routeIds: ['route_1'],
      ),
    ],
    reviews: const [],
    missions: [
      Mission(
        id: 'mission_1',
        spotId: 'spot_1',
        title: '낮은 참여 미션',
        authorNickname: 'tester',
        createdAt: DateTime.utc(2026),
        likeCount: 1,
        verificationCount: 2,
      ),
      Mission(
        id: 'mission_2',
        spotId: 'spot_1',
        title: '높은 참여 미션',
        authorNickname: 'tester',
        createdAt: DateTime.utc(2026),
        likeCount: 1,
        verificationCount: 5,
      ),
    ],
    galleryPhotos: const [],
  );
}

B4ySampleData _sampleDataWithShorterDownDirection() {
  final stops = [
    const BusStop(
      id: 'stop_a',
      name: 'A 정류장',
      position: LatLng(37, 126),
      sequence: 1,
    ),
    const BusStop(
      id: 'stop_mid_1',
      name: '중간 1',
      position: LatLng(37.05, 126.05),
      sequence: 2,
    ),
    const BusStop(
      id: 'stop_mid_2',
      name: '중간 2',
      position: LatLng(37.1, 126.1),
      sequence: 3,
    ),
    const BusStop(
      id: 'stop_b',
      name: 'B 정류장',
      position: LatLng(37.2, 126.2),
      sequence: 4,
    ),
  ];
  final route = BusRoute(
    id: 'route_1',
    number: '10',
    destination: 'B 정류장',
    directions: const [
      RouteDirection(
        id: 'up',
        name: '상행',
        destination: 'B 방면',
        stopIds: ['stop_a', 'stop_mid_1', 'stop_mid_2', 'stop_b'],
        shape: [
          LatLng(37, 126),
          LatLng(37.05, 126.05),
          LatLng(37.1, 126.1),
          LatLng(37.2, 126.2),
        ],
      ),
      RouteDirection(
        id: 'down',
        name: '하행',
        destination: 'B 빠른 방면',
        stopIds: ['stop_a', 'stop_b'],
        shape: [LatLng(37, 126), LatLng(37.2, 126.2)],
      ),
    ],
  );
  return B4ySampleData(
    stops: stops,
    routes: [route],
    routePhotoClusters: const [],
    touristSpots: const [
      TouristSpot(
        id: 'spot_1',
        name: '관광지',
        description: '설명',
        position: LatLng(37.204, 126.204),
        heroImageUrl: 'https://example.com/spot.jpg',
        nearestStopId: 'stop_b',
        routeIds: ['route_1'],
      ),
    ],
    reviews: const [],
    missions: const [],
    galleryPhotos: const [],
  );
}

B4ySampleData _sampleDataWithDistantTouristSpot() {
  final stops = [
    const BusStop(
      id: 'stop_a',
      name: 'A 정류장',
      position: LatLng(37, 126),
      sequence: 1,
    ),
    const BusStop(
      id: 'stop_b',
      name: 'B 정류장',
      position: LatLng(37.2, 126.2),
      sequence: 2,
    ),
  ];
  const route = BusRoute(
    id: 'route_1',
    number: '10',
    destination: 'B 정류장',
    directions: [
      RouteDirection(
        id: 'up',
        name: '상행',
        destination: 'B 방면',
        stopIds: ['stop_a', 'stop_b'],
        shape: [LatLng(37, 126), LatLng(37.2, 126.2)],
      ),
    ],
  );
  return B4ySampleData(
    stops: stops,
    routes: const [route],
    routePhotoClusters: const [],
    touristSpots: const [
      TouristSpot(
        id: 'spot_far',
        name: '먼 관광지',
        description: '설명',
        position: LatLng(37.215, 126.215),
        heroImageUrl: 'https://example.com/spot.jpg',
        nearestStopId: 'stop_b',
        routeIds: ['route_1'],
      ),
    ],
    reviews: const [],
    missions: const [],
    galleryPhotos: const [],
  );
}

B4ySampleData _sampleDataWithOppositeStopShortcut() {
  const stops = [
    BusStop(
      id: 'up_current',
      name: '현위치 정류장',
      position: LatLng(37, 126),
      sequence: 1,
    ),
    BusStop(
      id: 'up_mid_1',
      name: '상행 중간 1',
      position: LatLng(37.01, 126.01),
      sequence: 2,
    ),
    BusStop(
      id: 'up_mid_2',
      name: '상행 중간 2',
      position: LatLng(37.02, 126.02),
      sequence: 3,
    ),
    BusStop(
      id: 'up_mid_3',
      name: '상행 중간 3',
      position: LatLng(37.03, 126.03),
      sequence: 4,
    ),
    BusStop(
      id: 'up_spot',
      name: '관광지 상행 정류장',
      position: LatLng(37.04, 126.04),
      sequence: 5,
    ),
    BusStop(
      id: 'turn',
      name: '회차 정류장',
      position: LatLng(37.05, 126.05),
      sequence: 6,
    ),
    BusStop(
      id: 'down_current',
      name: '현위치 맞은편 정류장',
      position: LatLng(37.0003, 126),
      sequence: 7,
    ),
    BusStop(
      id: 'down_spot',
      name: '관광지 하행 정류장',
      position: LatLng(37.0403, 126.04),
      sequence: 8,
    ),
  ];
  const route = BusRoute(
    id: 'route_1',
    number: '10',
    destination: '회차 정류장',
    directions: [
      RouteDirection(
        id: 'up',
        name: '상행',
        destination: '회차 정류장 방면',
        stopIds: [
          'up_current',
          'up_mid_1',
          'up_mid_2',
          'up_mid_3',
          'up_spot',
          'turn',
        ],
        shape: [
          LatLng(37, 126),
          LatLng(37.01, 126.01),
          LatLng(37.02, 126.02),
          LatLng(37.03, 126.03),
          LatLng(37.04, 126.04),
          LatLng(37.05, 126.05),
        ],
      ),
      RouteDirection(
        id: 'down',
        name: '하행',
        destination: '출발지 방면',
        stopIds: ['turn', 'down_current', 'down_spot'],
        shape: [
          LatLng(37.05, 126.05),
          LatLng(37.0003, 126),
          LatLng(37.0403, 126.04),
        ],
      ),
    ],
  );
  return const B4ySampleData(
    stops: stops,
    routes: [route],
    routePhotoClusters: [],
    touristSpots: [
      TouristSpot(
        id: 'spot_1',
        name: '관광지',
        description: '설명',
        position: LatLng(37.04, 126.04),
        heroImageUrl: 'https://example.com/spot.jpg',
        nearestStopId: 'up_spot',
        routeIds: ['route_1'],
      ),
    ],
    reviews: [],
    missions: [],
    galleryPhotos: [],
  );
}

B4ySampleData _sampleDataWithTransferRoute() {
  const stops = [
    BusStop(
      id: 'origin_stop',
      name: '출발 정류장',
      position: LatLng(37, 126),
      sequence: 1,
    ),
    BusStop(
      id: 'transfer_stop',
      name: '환승 정류장',
      position: LatLng(37.1, 126.1),
      sequence: 2,
    ),
    BusStop(
      id: 'spot_stop',
      name: '관광지 정류장',
      position: LatLng(37.2, 126.2),
      sequence: 3,
    ),
    BusStop(
      id: 'spot_route_origin_side',
      name: '관광지 노선 반대 정류장',
      position: LatLng(37, 126),
      sequence: 4,
    ),
  ];
  const originRoute = BusRoute(
    id: 'route_origin',
    number: '11',
    destination: '환승 정류장',
    directions: [
      RouteDirection(
        id: 'up',
        name: '상행',
        destination: '환승 정류장 방면',
        stopIds: ['origin_stop', 'transfer_stop'],
        shape: [LatLng(37, 126), LatLng(37.1, 126.1)],
      ),
    ],
  );
  const spotRoute = BusRoute(
    id: 'route_spot',
    number: '22',
    destination: '관광지 정류장',
    directions: [
      RouteDirection(
        id: 'up',
        name: '상행',
        destination: '관광지 정류장 방면',
        stopIds: ['transfer_stop', 'spot_stop', 'spot_route_origin_side'],
        shape: [LatLng(37.1, 126.1), LatLng(37.2, 126.2), LatLng(37, 126)],
      ),
    ],
  );
  return const B4ySampleData(
    stops: stops,
    routes: [originRoute, spotRoute],
    routePhotoClusters: [],
    touristSpots: [
      TouristSpot(
        id: 'spot_1',
        name: '관광지',
        description: '설명',
        position: LatLng(37.205, 126.205),
        heroImageUrl: 'https://example.com/spot.jpg',
        nearestStopId: 'spot_stop',
        routeIds: ['route_spot'],
      ),
    ],
    reviews: [],
    missions: [],
    galleryPhotos: [],
  );
}

B4ySampleData _sampleDataWithDirectAndShorterTransferRoute() {
  const stops = [
    BusStop(
      id: 'origin_stop',
      name: 'Origin stop',
      position: LatLng(37, 126),
      sequence: 1,
    ),
    BusStop(
      id: 'direct_mid_1',
      name: 'Direct mid 1',
      position: LatLng(37.01, 126.01),
      sequence: 2,
    ),
    BusStop(
      id: 'direct_mid_2',
      name: 'Direct mid 2',
      position: LatLng(37.02, 126.02),
      sequence: 3,
    ),
    BusStop(
      id: 'direct_mid_3',
      name: 'Direct mid 3',
      position: LatLng(37.03, 126.03),
      sequence: 4,
    ),
    BusStop(
      id: 'spot_stop',
      name: 'Spot stop',
      position: LatLng(37.04, 126.04),
      sequence: 5,
    ),
    BusStop(
      id: 'transfer_stop',
      name: 'Transfer stop',
      position: LatLng(37.1, 126.1),
      sequence: 6,
    ),
    BusStop(
      id: 'spot_route_origin_side',
      name: 'Spot route origin side',
      position: LatLng(37, 126),
      sequence: 7,
    ),
  ];
  const directRoute = BusRoute(
    id: 'route_direct',
    number: '10',
    destination: 'Spot stop',
    directions: [
      RouteDirection(
        id: 'up',
        name: 'Up',
        destination: 'Spot stop',
        stopIds: [
          'origin_stop',
          'direct_mid_1',
          'direct_mid_2',
          'direct_mid_3',
          'spot_stop',
        ],
        shape: [
          LatLng(37, 126),
          LatLng(37.01, 126.01),
          LatLng(37.02, 126.02),
          LatLng(37.03, 126.03),
          LatLng(37.04, 126.04),
        ],
      ),
    ],
  );
  const originRoute = BusRoute(
    id: 'route_origin',
    number: '11',
    destination: 'Transfer stop',
    directions: [
      RouteDirection(
        id: 'up',
        name: 'Up',
        destination: 'Transfer stop',
        stopIds: ['origin_stop', 'transfer_stop'],
        shape: [LatLng(37, 126), LatLng(37.1, 126.1)],
      ),
    ],
  );
  const spotRoute = BusRoute(
    id: 'route_spot',
    number: '22',
    destination: 'Spot stop',
    directions: [
      RouteDirection(
        id: 'up',
        name: 'Up',
        destination: 'Spot stop',
        stopIds: ['transfer_stop', 'spot_stop', 'spot_route_origin_side'],
        shape: [LatLng(37.1, 126.1), LatLng(37.04, 126.04), LatLng(37, 126)],
      ),
    ],
  );
  return const B4ySampleData(
    stops: stops,
    routes: [directRoute, originRoute, spotRoute],
    routePhotoClusters: [],
    touristSpots: [
      TouristSpot(
        id: 'spot_1',
        name: 'Tourist spot',
        description: 'Description',
        position: LatLng(37.04, 126.04),
        heroImageUrl: 'https://example.com/spot.jpg',
        nearestStopId: 'spot_stop',
        routeIds: ['route_direct', 'route_spot'],
      ),
    ],
    reviews: [],
    missions: [],
    galleryPhotos: [],
  );
}
