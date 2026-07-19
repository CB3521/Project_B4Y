import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

/// Converts a platform [Placemark] into the short administrative address used
/// by the home screen. Missing components are simply omitted.
String formatAdministrativeAddress({
  String? administrativeArea,
  String? subAdministrativeArea,
  String? locality,
  String? subLocality,
  String? thoroughfare,
}) {
  final city = _firstNonEmpty([
    locality,
    subAdministrativeArea,
    administrativeArea,
  ]);
  final district = _firstNonEmpty([
    if (subAdministrativeArea != city) subAdministrativeArea,
    if (subLocality?.endsWith('구') == true) subLocality,
  ]);
  final neighborhood = _firstNonEmpty([
    if (subLocality != district) subLocality,
    thoroughfare,
  ]);

  final parts = <String>[];
  if (city != null) parts.add(_normalizeCityName(city));
  if (district != null && district != city) parts.add(district);
  if (neighborhood != null &&
      neighborhood != city &&
      neighborhood != district) {
    parts.add(neighborhood);
  }
  return parts.join(' ');
}

String _normalizeCityName(String value) {
  if (value.endsWith('특별시')) return '${value.substring(0, value.length - 3)}시';
  if (value.endsWith('광역시')) return '${value.substring(0, value.length - 3)}시';
  return value;
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

Future<String?> reverseGeocodeShortAddress(LatLng location) async {
  final placemarks = await Geocoding().placemarkFromCoordinates(
    location.latitude,
    location.longitude,
  );
  if (placemarks.isEmpty) return null;
  final placemark = placemarks.first;
  final address = formatAdministrativeAddress(
    administrativeArea: placemark.administrativeArea,
    subAdministrativeArea: placemark.subAdministrativeArea,
    locality: placemark.locality,
    subLocality: placemark.subLocality,
    thoroughfare: placemark.thoroughfare,
  );
  return address.isEmpty ? null : address;
}
