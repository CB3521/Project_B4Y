import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const maxImageDataUrlBytes = 360 * 1024;
const maxImageLongSidePixels = 768;
const imageJpegQuality = 55;

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
