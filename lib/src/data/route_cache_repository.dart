import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../domain/b4y_models.dart';

abstract class RouteCacheRepository {
  Future<List<BusRoute>> searchRoutes(String query);

  Future<void> cacheRoutes(List<BusRoute> routes);
}

class FirestoreRouteCacheRepository implements RouteCacheRepository {
  FirestoreRouteCacheRepository(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _routes =>
      firestore.collection('regional_routes');

  @override
  Future<List<BusRoute>> searchRoutes(String query) async {
    final normalizedQuery = normalizeRouteCacheQuery(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final snapshot = await _routes
        .where('searchPrefixes', arrayContains: normalizedQuery)
        .limit(80)
        .get();
    final routes = snapshot.docs
        .map(_routeFromSnapshot)
        .whereType<BusRoute>()
        .toList();
    routes.sort(_compareRoutes);
    return routes;
  }

  @override
  Future<void> cacheRoutes(List<BusRoute> routes) async {
    if (routes.isEmpty) {
      return;
    }

    final batch = firestore.batch();
    var hasWrites = false;
    for (final route in routes.take(80)) {
      final id = route.id.trim();
      if (id.isEmpty || id.contains('/')) {
        continue;
      }
      batch.set(_routes.doc(id), {
        'routeId': route.id,
        'number': route.number,
        'destination': route.destination,
        'routeType': route.routeType,
        'directions': _directionsForStorage(
          route,
        ).map(_directionToJson).toList(),
        'searchPrefixes': _searchPrefixesFor(route),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      hasWrites = true;
    }
    if (!hasWrites) {
      return;
    }
    await batch.commit();
  }

  BusRoute? _routeFromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    try {
      final directions = (data['directions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_directionFromJson)
          .toList();
      return BusRoute(
        id: (data['routeId'] as String?) ?? snapshot.id,
        number: data['number'] as String,
        destination: data['destination'] as String? ?? '',
        routeType: data['routeType'] as String? ?? '',
        directions: directions.isEmpty
            ? [
                RouteDirection(
                  id: '${snapshot.id}_default',
                  name: data['number'] as String,
                  destination: data['destination'] as String? ?? '',
                  stopIds: const [],
                  shape: const [],
                ),
              ]
            : directions,
      );
    } on Object {
      return null;
    }
  }
}

String normalizeRouteCacheQuery(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();

Map<String, dynamic> _directionToJson(RouteDirection direction) {
  return {
    'id': direction.id,
    'name': direction.name,
    'destination': direction.destination,
    'stopIds': direction.stopIds,
    'shape': direction.shape
        .map((point) => {'lat': point.latitude, 'lng': point.longitude})
        .toList(),
  };
}

List<RouteDirection> _directionsForStorage(BusRoute route) {
  if (route.directions.isNotEmpty) {
    return route.directions;
  }
  return [
    RouteDirection(
      id: '${route.id}_default',
      name: route.number,
      destination: route.destination,
      stopIds: const [],
      shape: const [],
    ),
  ];
}

RouteDirection _directionFromJson(Map<String, dynamic> json) {
  return RouteDirection(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    destination: json['destination'] as String? ?? '',
    stopIds: (json['stopIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    shape: (json['shape'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (point) => LatLng(
            (point['lat'] as num).toDouble(),
            (point['lng'] as num).toDouble(),
          ),
        )
        .toList(),
  );
}

List<String> _searchPrefixesFor(BusRoute route) {
  final normalizedNumber = normalizeRouteCacheQuery(route.number);
  final prefixes = <String>{};
  for (var index = 1; index <= normalizedNumber.length; index += 1) {
    prefixes.add(normalizedNumber.substring(0, index));
  }
  return prefixes.toList()..sort();
}

int _compareRoutes(BusRoute left, BusRoute right) {
  final leftNumber = int.tryParse(
    left.number.replaceAll(RegExp(r'[^0-9]'), ''),
  );
  final rightNumber = int.tryParse(
    right.number.replaceAll(RegExp(r'[^0-9]'), ''),
  );
  if (leftNumber != null && rightNumber != null && leftNumber != rightNumber) {
    return leftNumber.compareTo(rightNumber);
  }
  return left.number.compareTo(right.number);
}
