import 'package:flutter_test/flutter_test.dart';
import 'package:sarehny_mobile/src/api_client.dart';

void main() {
  test('site pages resolve to the PHP API origin', () {
    final api = ApiClient(baseUrl: 'https://stage.sarehny.example/api/v1/');

    expect(api.siteOrigin.origin, 'https://stage.sarehny.example');
    expect(
      api.sitePage('u.php', queryParameters: {'n': 'sara_99'}).toString(),
      'https://stage.sarehny.example/u.php?n=sara_99',
    );
  });

  test('site page resolver rejects path traversal and arbitrary paths', () {
    final api = ApiClient(baseUrl: 'https://stage.sarehny.example/api/v1/');

    expect(() => api.sitePage('../admin.php'), throwsA(isA<ApiException>()));
    expect(() => api.sitePage('https://other.example/admin.php'), throwsA(isA<ApiException>()));
  });

  test('site page resolver remains disabled without an explicit API URL', () {
    final api = ApiClient();

    expect(() => api.sitePage('index.php'), throwsA(isA<ApiException>()));
  });
}
