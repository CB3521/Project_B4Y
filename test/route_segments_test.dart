import 'package:b4y/src/domain/b4y_models.dart';
import 'package:b4y/src/domain/route_segments.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('finds the nearest segment from a GPS position', () {
    final route = _route(8);
    final data = B4ySampleData(
      stops: [for (var i = 0; i < 8; i++) _stop(i)],
      routes: [route],
      routePhotoClusters: const [],
      touristSpots: const [],
      reviews: const [],
      missions: const [],
      galleryPhotos: const [],
    );

    final segment = findNearestRouteSegment(
      route,
      data,
      const LatLng(37.065, 126),
    );

    expect(segment, isNotNull);
    expect(segment!.directionId, 'up');
    expect(segment.startStop.id, 'stop_4');
  });

  for (final count in [3, 4, 6, 7, 8, 9, 10]) {
    test('splits $count stops evenly', () {
      final route = _route(count);
      final data = B4ySampleData(
        stops: [for (var i = 0; i < count; i++) _stop(i)],
        routes: [route],
        routePhotoClusters: const [],
        touristSpots: const [],
        reviews: const [],
        missions: const [],
        galleryPhotos: const [],
      );

      final segments = buildRouteSegments(route, route.defaultDirection, data);

      expect(segments.expand((segment) => segment.stops), hasLength(count));
      expect(
        segments.map((segment) => segment.stops.length),
        everyElement(isIn([2, 3, 4])),
      );
      expect(segments.first.startStop.id, 'stop_0');
      expect(segments.last.endStop.id, 'stop_${count - 1}');
    });
  }
}

BusRoute _route(int count) {
  return BusRoute(
    id: 'route_test',
    number: '1',
    destination: '종점',
    directions: [
      RouteDirection(
        id: 'up',
        name: '상행',
        destination: '종점 방면',
        stopIds: [for (var i = 0; i < count; i++) 'stop_$i'],
        shape: [for (var i = 0; i < count; i++) LatLng(37.0 + i / 100, 126.0)],
      ),
    ],
  );
}

BusStop _stop(int index) {
  return BusStop(
    id: 'stop_$index',
    name: '정류장 $index',
    position: LatLng(37.0 + index / 100, 126.0),
    sequence: index,
  );
}
