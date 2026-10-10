import 'package:flutter_test/flutter_test.dart';
import 'package:sarehny_mobile/src/api_config.dart';

void main() {
  test('default API endpoint targets the local test server', () {
    expect(ApiConfig.apiBaseUrl, startsWith('http://10.0.2.2:8080/'));
    expect(ApiConfig.apiBaseUrl, contains('/api/v1/'));
    expect(ApiConfig.apiBaseUrl, isNot(contains('sarehny.com')));
  });
}
