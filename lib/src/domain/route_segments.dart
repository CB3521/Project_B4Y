import 'package:latlong2/latlong.dart';

import 'b4y_models.dart';

class RouteSegment {
  const RouteSegment({
    required this.routeId,
    required this.directionId,
    required this.index,
    required this.stops,
  });

  final String routeId;
  final String directionId;
  final int index;
  final List<BusStop> stops;

  BusStop get startStop => stops.first;
  BusStop get endStop => stops.last;
  LatLng get center => LatLng(
    (startStop.position.latitude + endStop.position.latitude) / 2,
    (startStop.position.longitude + endStop.position.longitude) / 2,
  );
}

List<RouteSegment> buildRouteSegments(
  BusRoute route,
  RouteDirection direction,
  B4ySampleData data,
) {
  final stops = direction.stopIds
      .map((id) => data.stopById(id))
      .toList(growable: false);
  if (stops.isEmpty) return const [];

  final segmentCount = (stops.length / 4).ceil().clamp(1, stops.length);
  final baseSize = stops.length ~/ segmentCount;
  final largerSegmentCount = stops.length % segmentCount;
  final segments = <RouteSegment>[];
  var offset = 0;
  for (var index = 0; index < segmentCount; index++) {
    final size = baseSize + (index < largerSegmentCount ? 1 : 0);
    segments.add(
      RouteSegment(
        routeId: route.id,
        directionId: direction.id,
        index: index,
        stops: stops.sublist(offset, offset + size),
      ),
    );
    offset += size;
  }
  return segments;
}

RouteSegment? findRouteSegment(
  Iterable<RouteSegment> segments, {
  required String directionId,
  required String startStopId,
  required String endStopId,
}) {
  for (final segment in segments) {
    if (segment.directionId == directionId &&
        segment.startStop.id == startStopId &&
        segment.endStop.id == endStopId) {
      return segment;
    }
  }
  return null;
}
