import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../site_browser.dart';

class SiteHubScreen extends StatefulWidget {
  const SiteHubScreen({
    super.key,
    required this.api,
    required this.displayName,
    required this.username,
    required this.isAdmin,
  });

  final ApiClient api;
  final String displayName;
  final String username;
  final bool isAdmin;

  @override
  State<SiteHubScreen> createState() => _SiteHubScreenState();
}

class _SiteHubScreenState extends State<SiteHubScreen> {
  String? _error;
  bool _opening = false;

  Future<void> _open(String path, {Map<String, String>? queryParameters}) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      await SiteBrowser.open(widget.api, path, queryParameters: queryParameters);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? 'تعذّر فتح صفحة الموقع.');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _section(String title, List<SiteDestination> destinations) => Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...destinations.map((destination) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Card(
                  child: ListTile(
                    leading: Icon(destination.icon, color: Theme.of(context).colorScheme.primary),
                    title: Text(destination.label),
                    subtitle: Text(destination.description),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: _opening ? null : () => _open(destination.path),
                  ),
                ),
              )),
        ]),
      );

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('موقع صراحة')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مرحبًا ${widget.displayName}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    'استكشف صفحات صراحة وميزاته الأصلية من داخل التطبيق، باستخدام جلسة حسابك الحالية.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.84)),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _opening ? null : () => _open(SitePagePaths.publicProfile, queryParameters: {'n': widget.username}),
                    icon: const Icon(Icons.person_outline_rounded),
                    label: const Text('افتح صفحتك العامة'),
                    style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onPrimary),
                  ),
                ]),
              ),
              if (_opening) const Padding(padding: EdgeInsets.only(top: 14), child: LinearProgressIndicator()),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              _section('صفحات الموقع', sitePublicDestinations),
              _section('حسابك وميزاته', siteAccountDestinations),
              if (widget.isAdmin)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Card(
                    child: ListTile(
                      leading: Icon(Icons.admin_panel_settings_outlined, color: Theme.of(context).colorScheme.primary),
                      title: const Text('لوحة الإدارة'),
                      subtitle: const Text('تتحقق من صلاحية المدير الأصلية على الخادم'),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: _opening ? null : () => _open(SitePagePaths.admin),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
