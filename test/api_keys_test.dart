import 'package:b4y/src/config/api_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiKeys parses configured json fields', () {
    final keys = ApiKeys.fromJson(const {
      'odsayApiKey': 'odsay-key',
      'gbisApiKey': 'gbis-key',
      'tourApiKey': 'tour-key',
      'kakaoMapKey': 'kakao-key',
    });

    expect(keys.odsayApiKey, 'odsay-key');
    expect(keys.gbisApiKey, 'gbis-key');
    expect(keys.tourApiKey, 'tour-key');
    expect(keys.kakaoMapKey, 'kakao-key');
    expect(keys.hasOdsayApiKey, isTrue);
    expect(keys.hasGbisApiKey, isTrue);
    expect(keys.hasTourApiKey, isTrue);
    expect(keys.hasKakaoMapKey, isTrue);
  });

  testWidgets('ApiKeys.load reads the local asset without throwing', (
    tester,
  ) async {
    final keys = await ApiKeys.load();

    expect(keys.odsayApiKey, isA<String>());
    expect(keys.gbisApiKey, isA<String>());
    expect(keys.tourApiKey, isA<String>());
    expect(keys.kakaoMapKey, isA<String>());
  });
}
