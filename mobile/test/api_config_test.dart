import 'package:flutter_test/flutter_test.dart';
import 'package:sarehny_mobile/src/api_client.dart';
import 'package:sarehny_mobile/src/api_config.dart';

void main() {
  test('API is not configured by default', () {
    expect(ApiConfig.apiBaseUrl, isEmpty);
    expect(ApiConfig.isConfigured, isFalse);
  });

  test('client refuses to send requests without an explicit API URL', () async {
    final client = ApiClient();

    await expectLater(
      client.session(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('لم يتم إرسال أي طلب API'),
        ),
      ),
    );
  });
}
