import 'package:flutter_test/flutter_test.dart';
import 'package:sarehny_mobile/src/api_client.dart';
import 'package:sarehny_mobile/src/api_config.dart';

void main() {
  test('production PHP API is configured by default', () {
    expect(ApiConfig.apiBaseUrl, 'https://sarehny.com/api/v1/');
    expect(ApiConfig.isConfigured, isTrue);
    expect(ApiClient().baseUrl, 'https://sarehny.com/api/v1/');
  });
}
