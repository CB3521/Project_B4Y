import 'package:b4y/src/data/route_cache_repository.dart';
import 'package:b4y/src/domain/b4y_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test(
    'Firestore route cache stores routes and searches by number prefix',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreRouteCacheRepository(firestore);

      await repository.cacheRoutes([
        const BusRoute(
          id: 'odsay_route_33',
          number: '33',
          destination: '안산역',
          routeType: '일반',
          directions: [
            RouteDirection(
              id: 'dir_1',
              name: '상행',
              destination: '안산역',
              stopIds: ['stop_1', 'stop_2'],
              shape: [LatLng(37.32, 126.78), LatLng(37.34, 126.8)],
            ),
          ],
        ),
        const BusRoute(
          id: 'odsay_route_99',
          number: '99',
          destination: '시흥시청',
          directions: [
            RouteDirection(
              id: 'dir_2',
              name: '상행',
              destination: '시흥시청',
              stopIds: [],
              shape: [],
            ),
          ],
        ),
      ]);

      final routes = await repository.searchRoutes('3');

      expect(routes.map((route) => route.id), ['odsay_route_33']);
      expect(routes.single.number, '33');
      expect(routes.single.defaultDirection.shape.length, 2);
    },
  );
}
