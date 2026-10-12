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
    expect(
      api.routeUri('theme-public').toString(),
      'https://stage.sarehny.example/api/v1/index.php?r=theme-public',
    );
    expect(
      api.routeUri('blog/posts/24').toString(),
      'https://stage.sarehny.example/api/v1/index.php?r=blog%2Fposts%2F24',
    );
    expect(
      api.routeUri('inbox', query: {'filter': 'all', 'sort': 'oldest', 'q': 'مرحبا'}).queryParameters,
      {'r': 'inbox', 'filter': 'all', 'sort': 'oldest', 'q': 'مرحبا'},
    );
    expect(
      api.supportUri(action: 'poll', after: 42).toString(),
      'https://stage.sarehny.example/support.php?a=poll&after=42',
    );
    expect(
      api.supportUri(action: 'send').toString(),
      'https://stage.sarehny.example/support.php?a=send&after=0',
    );
    expect(() => api.supportUri(action: 'admin_delete'), throwsA(isA<ApiException>()));
    expect(() => api.routeUri('../session'), throwsA(isA<ApiException>()));
  });

  test('API base URLs require HTTPS and reject embedded credentials or query data', () {
    expect(
      () => ApiClient(baseUrl: 'http://stage.sarehny.example/api/v1/'),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => ApiClient(baseUrl: 'https://user:password@stage.sarehny.example/api/v1/'),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => ApiClient(baseUrl: 'https://stage.sarehny.example/api/v1/?r=session'),
      throwsA(isA<ApiException>()),
    );
  });

  test('public profile URLs are generated from a validated username', () {
    final api = ApiClient(baseUrl: 'https://stage.sarehny.example/api/v1/');

    expect(api.siteOrigin.origin, 'https://stage.sarehny.example');
    expect(
      api.publicProfileUri('sara_99').toString(),
      'https://stage.sarehny.example/u.php?n=sara_99',
    );
    expect(() => api.publicProfileUri('../admin'), throwsA(isA<ApiException>()));
    expect(() => api.publicProfileUri(''), throwsA(isA<ApiException>()));
  });

  test('default profile links point to the original Sarehny site', () {
    final api = ApiClient();

    expect(api.publicProfileUri('sara_99').toString(), 'https://sarehny.com/u.php?n=sara_99');
  });
}
