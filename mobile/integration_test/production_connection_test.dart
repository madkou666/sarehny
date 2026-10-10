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

  testWidgets('production API session connects and the app opens its sign-in screen', (tester) async {
    expect(ApiConfig.isConfigured, isTrue);
    expect(ApiConfig.apiBaseUrl, 'https://sarehny.com/api/v1/');

    final api = ApiClient();
    final session = await api.session();
    expect(session['csrf'], isA<String>());
    expect((session['csrf'] as String).isNotEmpty, isTrue);
    expect(session['user'], isNull);

    app.main();
    await _settle(tester);

    expect(find.text('أهلًا بعودتك'), findsOneWidget);
    expect(find.textContaining('الاتصال بالخادم غير مهيأ'), findsNothing);
  });
}
