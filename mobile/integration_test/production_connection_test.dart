import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sarehny_mobile/main.dart' as app;
import 'package:sarehny_mobile/src/api_client.dart';
import 'package:sarehny_mobile/src/api_config.dart';

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
      const Duration(milliseconds: 250),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 60),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('production session and CSRF-protected login validation reach the PHP API', (tester) async {
    expect(ApiConfig.isConfigured, isTrue);
    expect(ApiConfig.apiBaseUrl, 'https://sarehny.com/api/v1/');

    final api = ApiClient();
    final session = await api.session();
    expect(session['csrf'], isA<String>());
    expect((session['csrf'] as String).isNotEmpty, isTrue);
    expect(session['user'], isNull);

    await expectLater(
      api.login('', ''),
      throwsA(isA<ApiException>().having((error) => error.statusCode, 'statusCode', 422)),
    );
    await expectLater(
      api.publicProfile('!'),
      throwsA(isA<ApiException>().having((error) => error.statusCode, 'statusCode', 422)),
    );
  });

  testWidgets('the APK opens its sign-in screen with the production API configured', (tester) async {
    expect(ApiConfig.isConfigured, isTrue);
    app.main();
    await _settle(tester);

    expect(find.text('أهلًا بعودتك'), findsOneWidget);
    expect(find.textContaining('الاتصال بالخادم غير مهيأ'), findsNothing);
  });
}
