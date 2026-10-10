import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'app_theme.dart';
import 'models.dart';
import 'screens/account_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/login_screen.dart';
import 'screens/public_message_screen.dart';

class SarehnyApp extends StatefulWidget {
  const SarehnyApp({super.key});
  @override
  State<SarehnyApp> createState() => _SarehnyAppState();
}

class _SarehnyAppState extends State<SarehnyApp> {
  final ApiClient _api = ApiClient();
  late Future<Map<String, dynamic>> _bootstrap;
  AppUser? _user;

  @override
  void initState() { super.initState(); _bootstrap = _api.session(); }

  void _setUser(AppUser? user) => setState(() => _user = user);

  Future<void> _logout() async {
    try { await _api.logout(); } finally { if (mounted) _setUser(null); }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'صراحة',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildSarehnyTheme(),
        home: FutureBuilder<Map<String, dynamic>>(
          future: _bootstrap,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const _SplashScreen();
            if (snapshot.hasError) return _OfflineScreen(onRetry: () => setState(() => _bootstrap = _api.session()));
            if (snapshot.hasData) {
              final value = snapshot.data!['user'];
              if (value is Map<String, dynamic>) _user ??= AppUser.fromJson(value);
            }
            if (_user == null) return LoginScreen(api: _api, onSignedIn: _setUser);
            return _HomeShell(api: _api, user: _user!, onLogout: _logout);
          },
        ),
      );
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.api, required this.user, required this.onLogout});
  final ApiClient api;
  final AppUser user;
  final Future<void> Function() onLogout;
  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: IndexedStack(index: _index, children: [
            InboxScreen(api: widget.api),
            PublicMessageScreen(api: widget.api),
            AccountScreen(api: widget.api, user: widget.user, onLogout: widget.onLogout),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox_rounded), label: 'الرسائل'),
              NavigationDestination(icon: Icon(Icons.send_outlined), selectedIcon: Icon(Icons.send_rounded), label: 'إرسال'),
              NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'حسابي'),
            ],
          ),
        ),
      );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 68, height: 68, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 32)),
            const SizedBox(height: 18),
            Text('صراحة', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 22),
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ])),
        ),
      );
}

class _OfflineScreen extends StatelessWidget {
  const _OfflineScreen({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: SarehnyColors.primary),
            const SizedBox(height: 16),
            Text(ApiConfig.isConfigured ? 'تعذّر الاتصال بخادم الاختبار' : 'الخادم غير مهيأ للاختبار', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              ApiConfig.isConfigured
                  ? 'تحقق من اتصال خادم الاختبار وتوفّره، ثم حاول مرة أخرى.'
                  : 'هذه نسخة آمنة بلا عنوان API افتراضي؛ لم يتم إرسال طلب إلى موقع الإنتاج أو إلى خادم وهمي. لاستخدام وظائف الحساب والرسائل، حدّد عنوان خادم اختبار حقيقي بعد تجهيزه.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SarehnyColors.muted),
            ),
            if (ApiConfig.isConfigured) ...[
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
            ],
          ]))),
        ),
      );
}
