import 'package:b4y/src/application/b4y_providers.dart';
import 'package:b4y/src/domain/b4y_models.dart';
import 'package:b4y/src/presentation/screens/home_screen.dart';
import 'package:b4y/src/presentation/widgets/kakao_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets(
    'home search screen shows nearby route prefixes and tourist names',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          b4yDataProvider.overrideWith((ref) async => _searchData),
          currentLocationProvider.overrideWith(
            (ref) async => const LatLng(37.36, 126.74),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final mainMap = tester.widget<KakaoMapView>(
        find.byKey(const Key('route-map')),
      );
      expect(mainMap.polylines[2].color, const Color(0xFFE53935));
      expect(mainMap.polylines[3].color, const Color(0xFF34A853));
      final snappedStopMarker = mainMap.markers.singleWhere(
        (marker) => marker.title == '시흥 정류장 · 33번, 3101번, 3111번',
      );
      expect(snappedStopMarker.point, const LatLng(37.35, 126.74));
      expect(
        tester.getTopLeft(find.text('33')).dy,
        lessThan(tester.getTopLeft(find.text('안산역')).dy),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('home-search-entry')));
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('home-search-input'));
      await tester.enterText(searchField, '오이도');
      await tester.pump();
      expect(find.text('오이도 빨강등대'), findsOneWidget);
      await tester.tap(find.text('오이도 빨강등대'));
      await tester.pumpAndSettle();
      expect(container.read(mapSearchCenterProvider), isNull);
      expect(find.text('경기도 시흥시 오이도로 175'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home-search-entry')));
      await tester.pumpAndSettle();
      await tester.enterText(searchField, '3');
      await tester.pump();
      expect(find.text('33'), findsOneWidget);
      expect(find.text('3101'), findsOneWidget);
      expect(find.text('3111'), findsOneWidget);
      expect(find.text('700'), findsNothing);

      await tester.tap(find.text('33'));
      await tester.pumpAndSettle();
      expect(container.read(selectedRouteProvider)?.routeId, 'route_33');

      await tester.tap(find.byKey(const Key('home-search-entry')));
      await tester.pumpAndSettle();
      await tester.enterText(searchField, '9');
      await tester.pump();
      expect(find.text('검색 결과가 없어요.'), findsOneWidget);
    },
  );
}

const _searchData = B4ySampleData(
  stops: [
    BusStop(
      id: 'siheung_stop',
      name: '시흥 정류장',
      position: LatLng(37.36, 126.74),
      sequence: 1,
    ),
    BusStop(
      id: 'seoul_stop',
      name: '서울 정류장',
      position: LatLng(37.56, 126.98),
      sequence: 1,
    ),
  ],
  routes: [
    BusRoute(
      id: 'route_33',
      number: '33',
      destination: '안산역',
      directions: [
        RouteDirection(
          id: 'up',
          name: '상행',
          destination: '안산역 방면',
          stopIds: ['siheung_stop'],
          shape: [LatLng(37.35, 126.73), LatLng(37.35, 126.75)],
        ),
      ],
    ),
    BusRoute(
      id: 'route_700',
      number: '700',
      destination: '서울역',
      directions: [
        RouteDirection(
          id: 'up',
          name: '상행',
          destination: '서울역 방면',
          stopIds: ['seoul_stop'],
          shape: [LatLng(37.56, 126.98)],
        ),
      ],
    ),
    BusRoute(
      id: 'route_3101',
      number: '3101',
      destination: '시흥시청',
      directions: [
        RouteDirection(
          id: 'up',
          name: '상행',
          destination: '시흥시청 방면',
          stopIds: ['siheung_stop'],
          shape: [LatLng(37.35, 126.74)],
        ),
      ],
    ),
    BusRoute(
      id: 'route_3111',
      number: '3111',
      destination: '시흥시청',
      directions: [
        RouteDirection(
          id: 'up',
          name: '상행',
          destination: '시흥시청 방면',
          stopIds: ['siheung_stop'],
          shape: [LatLng(37.35, 126.74)],
        ),
      ],
    ),
  ],
  routePhotoClusters: [],
  touristSpots: [
    TouristSpot(
      id: 'spot_oido',
      name: '오이도 빨강등대',
      description: '해안 관광지',
      address: '경기도 시흥시 오이도로 175',
      position: LatLng(37.3455, 126.6871),
      heroImageUrl: '',
      nearestStopId: 'siheung_stop',
      routeIds: ['route_33'],
    ),
  ],
  reviews: [],
  missions: [],
  galleryPhotos: [],
);
