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
    required this.onOpenInbox,
    required this.onSendMessage,
  });

  final ApiClient api;
  final String displayName;
  final String username;
  final bool isAdmin;
  final VoidCallback onOpenInbox;
  final VoidCallback onSendMessage;

  @override
  State<SiteHubScreen> createState() => _SiteHubScreenState();
}

class _SiteHubScreenState extends State<SiteHubScreen> {
  String? _error;
  bool _opening = false;
  late Future<Map<String, dynamic>> _overview;

  @override
  void initState() {
    super.initState();
    _overview = widget.api.account();
  }

  Future<void> _copyProfileLink() async {
    final link = widget.api.sitePage(SitePagePaths.publicProfile, queryParameters: {'n': widget.username}).toString();
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ رابطك الشخصي.')));
  }

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
          appBar: AppBar(title: const Text('الرئيسية')),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() => _overview = widget.api.account());
              try {
                await _overview;
              } catch (_) {}
            },
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: widget.onOpenInbox, icon: const Icon(Icons.inbox_outlined), label: const Text('صندوق الرسائل'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: widget.onSendMessage, icon: const Icon(Icons.send_outlined), label: const Text('إرسال رسالة'))),
              ]),
              const SizedBox(height: 14),
              FutureBuilder<Map<String, dynamic>>(
                future: _overview,
                builder: (context, snapshot) {
                  final stats = snapshot.data?['stats'];
                  if (stats is! Map) return const SizedBox.shrink();
                  int count(String key) => (stats[key] as num?)?.toInt() ?? 0;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('ملخص حسابك', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _OverviewStat(label: 'الرسائل', value: count('total'))),
                          Expanded(child: _OverviewStat(label: 'اليوم', value: count('today'))),
                          Expanded(child: _OverviewStat(label: 'الأسئلة المعلّقة', value: count('pending'))),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
              Card(
                child: ListTile(
                  leading: Icon(Icons.link_rounded, color: Theme.of(context).colorScheme.primary),
                  title: const Text('رابطك الشخصي'),
                  subtitle: Text(widget.api.sitePage(SitePagePaths.publicProfile, queryParameters: {'n': widget.username}).toString(), textDirection: TextDirection.ltr, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(tooltip: 'نسخ الرابط', onPressed: _copyProfileLink, icon: const Icon(Icons.copy_rounded)),
                ),
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
        ),
      );
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
