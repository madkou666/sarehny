import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sarehny_mobile/main.dart' as app;
import 'package:sarehny_mobile/src/api_client.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _stagingUsername = String.fromEnvironment('STAGING_USERNAME');
const _stagingPassword = String.fromEnvironment('STAGING_PASSWORD');

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
      const Duration(milliseconds: 250),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 90),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('staging login, account setting, inbox, message delivery, deletion, and logout', (tester) async {
    if (_apiBaseUrl.isEmpty || _stagingUsername.isEmpty || _stagingPassword.isEmpty) {
      fail('Configure API_BASE_URL and dedicated staging credentials before running this test.');
    }

    final marker = 'اختبار تكامل صراحة ${DateTime.now().millisecondsSinceEpoch}';
    var messageMayExist = false;
    var profileMayHaveChanged = false;
    String? originalDisplayName;
    final cleanupApi = ApiClient(baseUrl: _apiBaseUrl);

    addTearDown(() async {
      if (!messageMayExist && !profileMayHaveChanged) return;
      try {
        final session = await cleanupApi.session();
        final currentUser = session['user'];
        if (currentUser is! Map || currentUser['username'] != _stagingUsername) {
          await cleanupApi.login(_stagingUsername, _stagingPassword);
        }
        if (profileMayHaveChanged && originalDisplayName != null) {
          await cleanupApi.updateProfile(originalDisplayName!);
        }
        if (messageMayExist) {
          final inbox = await cleanupApi.inbox(limit: 50);
          final messages = inbox['messages'];
          if (messages is List) {
            for (final item in messages) {
              if (item is Map && item['body'] == marker && item['id'] is num) {
                await cleanupApi.messageAction((item['id'] as num).toInt(), 'delete');
              }
            }
          }
        }
        await cleanupApi.logout();
      } on Object catch (error) {
        fail('Staging cleanup failed (${error.runtimeType}); verify the dedicated test account and remove only this run’s test data.');
      }
    });

    final initialSession = await cleanupApi.session();
    expect(initialSession['user'], isNull);
    final theme = await cleanupApi.appTheme();
    expect(theme['theme'], isA<Map<String, dynamic>>());

    app.main();
    await _settle(tester);

    expect(find.text('أهلًا بعودتك'), findsOneWidget);
    final loginFields = find.byType(TextFormField);
    await tester.enterText(loginFields.at(0), _stagingUsername);
    await tester.enterText(loginFields.at(1), _stagingPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await _settle(tester);
    expect(find.text('موقع صراحة'), findsOneWidget);

    await tester.tap(find.text('حسابي').last);
    await _settle(tester);
    expect(find.text('اسم المستخدم'), findsOneWidget);
    expect(find.text('@$_stagingUsername'), findsWidgets);

    final account = await cleanupApi.account();
    final accountUser = account['user'];
    expect(accountUser, isA<Map>());
    originalDisplayName = (accountUser as Map)['display_name'] as String?;
    expect(originalDisplayName, isNotNull);
    final updatedDisplayName = 'اختبار صراحة ${DateTime.now().millisecondsSinceEpoch}';
    profileMayHaveChanged = true;
    await tester.tap(find.widgetWithText(FilledButton, 'تعديل الاسم الظاهر'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).last, updatedDisplayName);
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await _settle(tester);
    expect(find.text('تم تحديث الاسم على حسابك.'), findsOneWidget);
    final updatedAccount = await cleanupApi.account();
    expect((updatedAccount['user'] as Map)['display_name'], updatedDisplayName);
    final restoredUser = await cleanupApi.updateProfile(originalDisplayName!);
    expect(restoredUser.displayName, originalDisplayName);
    profileMayHaveChanged = false;

    await tester.tap(find.text('إرسال').last);
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, _stagingUsername);
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await _settle(tester);
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, marker);
    messageMayExist = true;
    await tester.tap(find.widgetWithText(FilledButton, 'إرسال دون اسم'));
    await _settle(tester);
    expect(find.text('وصلت رسالتك إلى صندوقه.'), findsOneWidget);

    await tester.tap(find.text('الرسائل').last);
    await _settle(tester);
    await tester.tap(find.byTooltip('تحديث الرسائل'));
    await _settle(tester);
    expect(find.text(marker), findsOneWidget);

    final messageCard = find.ancestor(of: find.text(marker), matching: find.byType(Card)).first;
    await tester.tap(find.descendant(of: messageCard, matching: find.byTooltip('إجراءات الرسالة')));
    await _settle(tester);
    await tester.tap(find.text('حذف الرسالة').last);
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await _settle(tester);
    expect(find.text(marker), findsNothing);
    messageMayExist = false;

    await tester.tap(find.text('حسابي').last);
    await _settle(tester);
    await tester.tap(find.text('تسجيل الخروج').last);
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الخروج'));
    await _settle(tester);
    expect(find.text('أهلًا بعودتك'), findsOneWidget);
  });
}
