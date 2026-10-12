import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import 'native_site_screen.dart';
import 'support_screen.dart';

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
  late Future<Map<String, dynamic>> _overview;

  @override
  void initState() {
    super.initState();
    _overview = widget.api.account();
  }

  Future<void> _refresh() async {
    setState(() => _overview = widget.api.account());
    try {
      await _overview;
    } catch (_) {}
  }

  Future<void> _copyProfileLink() async {
    try {
      final link = widget.api.publicProfileUri(widget.username).toString();
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ رابطك الشخصي.')));
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _openPage(NativeSitePage page) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NativeSiteScreen(api: widget.api, page: page),
    ));
  }

  void _openProfile() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NativeSiteScreen(api: widget.api, page: NativeSitePage.profile, username: widget.username),
    ));
  }

  void _openSupport() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SupportScreen(api: widget.api),
    ));
  }

  void _openUnavailable(String title, String detail) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NativeFeatureUnavailableScreen(title: title, detail: detail),
    ));
  }

  Widget _section(String title, List<_NativeDestination> destinations) => Padding(
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
                    trailing: const Icon(Icons.chevron_left_rounded, size: 20),
                    onTap: () {
                      if (destination.support) {
                        _openSupport();
                      } else if (destination.page != null) {
                        _openPage(destination.page!);
                      } else {
                        _openUnavailable(destination.label, destination.unavailableDetail!);
                      }
                    },
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
            onRefresh: _refresh,
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
                      'كل ما تحتاجه لإدارة رسائلك ومشاركة رابطك، بواجهات Flutter أصلية.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.84)),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _openProfile,
                      icon: const Icon(Icons.person_outline_rounded),
                      label: const Text('معاينة ملفك العام'),
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Card(child: Padding(padding: EdgeInsets.all(18), child: LinearProgressIndicator()));
                    }
                    if (snapshot.hasError) {
                      return Card(child: ListTile(leading: const Icon(Icons.cloud_off_outlined), title: const Text('تعذّر تحديث ملخص الحساب'), trailing: IconButton(tooltip: 'إعادة المحاولة', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))));
                    }
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
                    subtitle: Text(widget.api.publicProfileUri(widget.username).toString(), textDirection: TextDirection.ltr, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(tooltip: 'نسخ الرابط', onPressed: _copyProfileLink, icon: const Icon(Icons.copy_rounded)),
                  ),
                ),
                _section('صفحات الموقع الأصلية', const [
                  _NativeDestination(label: 'الصفحة الرئيسية', description: 'تعريف الخدمة وأحدث المقالات', icon: Icons.home_outlined, page: NativeSitePage.home),
                  _NativeDestination(label: 'مدونة أسرار', description: 'المقالات المنشورة من الخادم', icon: Icons.article_outlined, page: NativeSitePage.blog),
                  _NativeDestination(label: 'من نحن', description: 'محتوى التعريف المحفوظ على الموقع', icon: Icons.info_outline_rounded, page: NativeSitePage.about),
                  _NativeDestination(label: 'اتصل بنا', description: 'إرسال استفسار إلى فريق الموقع', icon: Icons.mail_outline_rounded, page: NativeSitePage.contact),
                  _NativeDestination(label: 'الدعم الفني', description: 'تابع محادثة الموقع وأرسل رسالة لفريق الدعم', icon: Icons.support_agent_rounded, support: true),
                ]),
                _section('ميزات تحتاج واجهات API أصلية إضافية', [
                  const _NativeDestination(label: 'الرسائل الصوتية', description: 'التسجيل ورفع الملفات والتشغيل غير مربوطين بعد', icon: Icons.mic_none_rounded, unavailableDetail: 'يحتاج الصوت API آمنًا لتسجيل المقاطع ورفعها وتسليمها وتشغيلها، إلى جانب صلاحية الميكروفون واختبار Android.'),
                  const _NativeDestination(label: 'الإحصاءات والتحليلات', description: 'تتطلب API يحدد الصلاحية ويعيد بيانات الحساب', icon: Icons.query_stats_rounded, unavailableDetail: 'لا توجد حاليًا نقطة API أصلية لبيانات الإحصاءات أو تفاصيل تحليل المرسل.'),
                  const _NativeDestination(label: 'المختبر الاجتماعي', description: 'يحتاج تدقيق واجهة PHP وحصص الذكاء الاصطناعي', icon: Icons.science_outlined, unavailableDetail: 'للموقع API مستقل للمختبر، لكنه يهيّئ جداول ديناميكيًا ويستهلك حصص مزوّد AI عند التوليد. لم أستدعِه من التطبيق قبل تدقيق تغييرات قاعدة البيانات والتكلفة وموافقة الخصوصية واختباره على staging.'),
                  const _NativeDestination(label: 'الإشعارات', description: 'Push Android يتطلب إعداد FCM على الخادم والتطبيق', icon: Icons.notifications_none_rounded, unavailableDetail: 'إعداد Firebase ومفتاح الإرسال وتسجيل أجهزة Android غير متوفر في المشروع؛ لن أظهر مفتاحًا شكليًا لا يحفظ تفضيلًا حقيقيًا.'),
                ]),
                if (widget.isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Card(
                      child: ListTile(
                        leading: Icon(Icons.admin_panel_settings_outlined, color: Theme.of(context).colorScheme.primary),
                        title: const Text('لوحة الإدارة'),
                        subtitle: const Text('يتطلب تنفيذًا أصليًا لواجهات الإدارة والصلاحيات'),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => _openUnavailable('لوحة الإدارة', 'تحتوي لوحة الموقع على أدوات إدارة حساسة ولا يوفر API الحالي عمليات إدارية Flutter. يلزم تصميم API لكل عملية مع تحقق صلاحيات/CSRF واختباره بحساب مدير staging؛ لن تُفتح لوحة PHP داخل WebView.'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _NativeDestination {
  const _NativeDestination({required this.label, required this.description, required this.icon, this.page, this.unavailableDetail, this.support = false});

  final String label;
  final String description;
  final IconData icon;
  final NativeSitePage? page;
  final String? unavailableDetail;
  final bool support;
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
