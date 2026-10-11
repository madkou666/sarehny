import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'api_client.dart';
import 'app_theme.dart';
import 'models.dart';
import 'screens/account_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/login_screen.dart';
import 'screens/public_message_screen.dart';
import 'screens/site_hub_screen.dart';

class SarehnyApp extends StatefulWidget {
  const SarehnyApp({super.key});
  @override
  State<SarehnyApp> createState() => _SarehnyAppState();
}

class _SarehnyAppState extends State<SarehnyApp> with WidgetsBindingObserver {
  final ApiClient _api = ApiClient();
  late Future<Map<String, dynamic>> _bootstrap;
  Timer? _themeRefreshTimer;
  AppUser? _user;
  SarehnyPalette _palette = SarehnyPalette.defaults;
  int _themeRequestId = 0;
  bool _refreshingSession = false;

  @override
  void initState() {
    super.initState();
    _api.onUnauthorized = () => unawaited(_refreshSession());
    WidgetsBinding.instance.addObserver(this);
    _themeRefreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(_refreshTheme());
    });
    _bootstrap = _api.session();
    _initializeTheme();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshTheme());
      unawaited(_refreshSession());
    }
  }

  Future<void> _refreshSession() async {
    if (_refreshingSession) return;
    _refreshingSession = true;
    try {
      final data = await _api.session();
      final value = data['user'];
      final refreshedUser = value is Map<String, dynamic> ? AppUser.fromJson(value) : null;
      if (mounted &&
          (refreshedUser?.id != _user?.id ||
              refreshedUser?.username != _user?.username ||
              refreshedUser?.displayName != _user?.displayName ||
              refreshedUser?.email != _user?.email ||
              refreshedUser?.avatarUrl != _user?.avatarUrl ||
              refreshedUser?.isAdmin != _user?.isAdmin ||
              refreshedUser?.insightsEnabled != _user?.insightsEnabled)) {
        setState(() {
          _user = refreshedUser;
          _bootstrap = Future<Map<String, dynamic>>.value(data);
        });
      }
    } catch (_) {
    } finally {
      _refreshingSession = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTheme() async {
    try {
      await _bootstrap;
    } catch (_) {}
    await _refreshTheme();
  }

  Future<void> _refreshTheme() async {
    final requestId = ++_themeRequestId;
    try {
      final data = await _api.appTheme();
      final value = data['theme'];
      if (!mounted || requestId != _themeRequestId || value is! Map<String, dynamic>) return;
      setState(() => _palette = SarehnyPalette.fromServer(value));
    } catch (_) {}
  }

  void _setUser(AppUser? user) => setState(() => _user = user);

  Future<void> _logout() async {
    try {
      await _api.logout();
    } finally {
      if (mounted) {
        setState(() {
          _user = null;
          _bootstrap = _api.session();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'صراحة',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildSarehnyTheme(_palette),
        home: FutureBuilder<Map<String, dynamic>>(
          future: _bootstrap,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const _SplashScreen();
            if (snapshot.hasError) {
              return _OfflineScreen(
                apiBaseUrl: _api.baseUrl,
                error: snapshot.error!,
                onRetry: () {
                  setState(() => _bootstrap = _api.session());
                  _initializeTheme();
                },
              );
            }
            if (snapshot.hasData) {
              final value = snapshot.data!['user'];
              if (value is Map<String, dynamic>) _user ??= AppUser.fromJson(value);
            }
            if (_user == null) return LoginScreen(api: _api, onSignedIn: _setUser);
            return _HomeShell(
              api: _api,
              user: _user!,
              onLogout: _logout,
              onUserUpdated: (user) => _setUser(user),
            );
          },
        ),
      );
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.api, required this.user, required this.onLogout, required this.onUserUpdated});
  final ApiClient api;
  final AppUser user;
  final Future<void> Function() onLogout;
  final ValueChanged<AppUser> onUserUpdated;
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
            SiteHubScreen(
              api: widget.api,
              displayName: widget.user.displayName,
              username: widget.user.username,
              isAdmin: widget.user.isAdmin,
              onOpenInbox: () => setState(() => _index = 1),
              onSendMessage: () => setState(() => _index = 2),
            ),
            InboxScreen(api: widget.api),
            PublicMessageScreen(api: widget.api),
            AccountScreen(
              api: widget.api,
              user: widget.user,
              onLogout: widget.onLogout,
              onUserUpdated: widget.onUserUpdated,
            ),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
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
            Container(width: 68, height: 68, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(22)), child: Icon(Icons.lock_outline_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 32)),
            const SizedBox(height: 18),
            Text('صراحة', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 22),
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ])),
        ),
      );
}

class _OfflineScreen extends StatelessWidget {
  const _OfflineScreen({
    required this.apiBaseUrl,
    required this.error,
    required this.onRetry,
  });

  final String apiBaseUrl;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_outlined, size: 48, color: Theme.of(context).extension<SarehnyPalette>()!.primary),
                  const SizedBox(height: 16),
                  Text('تعذّر الاتصال بخادم صراحة', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).extension<SarehnyPalette>()!.muted),
                  ),
                  if (apiBaseUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      'عنوان API المستخدم: $apiBaseUrl',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
