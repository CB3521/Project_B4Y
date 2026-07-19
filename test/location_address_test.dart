import 'package:b4y/src/data/location_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats a city and neighborhood without parentheses', () {
    expect(
      formatAdministrativeAddress(
        administrativeArea: '경기도',
        locality: '시흥시',
        subLocality: '정왕동',
      ),
      '시흥시 정왕동',
    );
  });

  test('formats a metropolitan city, district, and neighborhood', () {
    expect(
      formatAdministrativeAddress(
        administrativeArea: '서울특별시',
        locality: '서울특별시',
        subAdministrativeArea: '중구',
        subLocality: '명동',
      ),
      '서울시 중구 명동',
    );
  });

  test('omits missing administrative components', () {
    expect(
      formatAdministrativeAddress(administrativeArea: '경기도'),
      '경기도',
    );
  });
}
