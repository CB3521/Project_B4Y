import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:latlong2/latlong.dart';

const maxImageDataUrlBytes = 360 * 1024;
const maxImageLongSidePixels = 768;
const imageJpegQuality = 55;

/// GPS coordinates embedded in an image's EXIF metadata.
class ImageGpsLocation {
  const ImageGpsLocation(this.position);

  final LatLng position;
}

ImageGpsLocation? extractImageGpsLocation(Uint8List source) {
  try {
    final decoded = img.decodeImage(source);
    if (decoded == null || !decoded.hasExif) return null;

    final gps = decoded.exif.gpsIfd;
    final latitude = gps.gpsLatitude;
    final longitude = gps.gpsLongitude;
    if (latitude == null || longitude == null) return null;

    final lat = _applyGpsReference(latitude, gps.gpsLatitudeRef, 'S');
    final lng = _applyGpsReference(longitude, gps.gpsLongitudeRef, 'W');
    if (lat.isNaN || lng.isNaN || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return ImageGpsLocation(LatLng(lat, lng));
  } on Object {
    // A malformed or unsupported EXIF block must not prevent an upload.
    return null;
  }
}

double _applyGpsReference(double value, String? reference, String negative) {
  return reference?.toUpperCase() == negative ? -value.abs() : value.abs();
}

String encodeImageDataUrl(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('지원하지 않는 이미지 형식입니다.');
  }
  final resized =
      decoded.width <= maxImageLongSidePixels &&
          decoded.height <= maxImageLongSidePixels
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height
              ? maxImageLongSidePixels
              : null,
          height: decoded.height > decoded.width
              ? maxImageLongSidePixels
              : null,
        );
  final encoded = Uint8List.fromList(
    img.encodeJpg(resized, quality: imageJpegQuality),
  );
  final dataUrl = 'data:image/jpeg;base64,${base64Encode(encoded)}';
  if (utf8.encode(dataUrl).length > maxImageDataUrlBytes) {
    throw const FormatException('이미지가 너무 큽니다. 더 작은 사진을 선택해 주세요.');
  }
  return dataUrl;
}

Uint8List? decodeImageDataUrl(String? value) {
  if (value == null || !value.startsWith('data:image/')) return null;
  final comma = value.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(value.substring(comma + 1));
  } on FormatException {
    return null;
  }
}
