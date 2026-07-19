import 'dart:convert';

import 'package:flutter/services.dart';

class ApiKeys {
  const ApiKeys({
    required this.odsayApiKey,
    required this.gbisApiKey,
    required this.tourApiKey,
    required this.kakaoMapKey,
  });

  factory ApiKeys.fromJson(Map<String, dynamic> json) {
    return ApiKeys(
      odsayApiKey: json['odsayApiKey'] as String? ?? '',
      gbisApiKey: json['gbisApiKey'] as String? ?? '',
      tourApiKey: json['tourApiKey'] as String? ?? '',
      kakaoMapKey: json['kakaoMapKey'] as String? ?? '',
    );
  }

  static const empty = ApiKeys(
    odsayApiKey: '',
    gbisApiKey: '',
    tourApiKey: '',
    kakaoMapKey: '',
  );

  static Future<ApiKeys> load() async {
    try {
      final rawJson = await rootBundle.loadString(
        'assets/config/api_keys.json',
      );
      return ApiKeys.fromJson(jsonDecode(rawJson) as Map<String, dynamic>);
    } on Object {
      return empty;
    }
  }

  final String odsayApiKey;
  final String gbisApiKey;
  final String tourApiKey;
  final String kakaoMapKey;

  bool get hasOdsayApiKey => odsayApiKey.trim().isNotEmpty;
  bool get hasGbisApiKey => gbisApiKey.trim().isNotEmpty;
  bool get hasTourApiKey => tourApiKey.trim().isNotEmpty;
  bool get hasKakaoMapKey => kakaoMapKey.trim().isNotEmpty;
}
