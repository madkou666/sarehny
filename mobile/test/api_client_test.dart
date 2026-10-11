import 'package:flutter_test/flutter_test.dart';
import 'package:sarehny_mobile/src/api_client.dart';

void main() {
  test('API routes resolve through index.php with the expected query route', () {
    final api = ApiClient(baseUrl: 'https://stage.sarehny.example/api/v1/');

    expect(
      api.routeUri('session').toString(),
      'https://stage.sarehny.example/api/v1/index.php?r=session',
    );
    expect(
      api.routeUri('auth/login').toString(),
      'https://stage.sarehny.example/api/v1/index.php?r=auth%2Flogin',
    );
    expect(
      api.routeUri('app-theme').toString(),
      'https://stage.sarehny.example/api/v1/index.php?r=app-theme',
    );
    expect(() => api.routeUri('../session'), throwsA(isA<ApiException>()));
  });

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

  test('default site pages resolve to the original Sarehny production site', () {
    final api = ApiClient();

    expect(api.sitePage('index.php').toString(), 'https://sarehny.com/index.php');
  });
}
