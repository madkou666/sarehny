import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../app_theme.dart';
import '../models.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.api, required this.user, required this.onLogout});
  final ApiClient api;
  final AppUser user;
  final Future<void> Function() onLogout;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late String _displayName = widget.user.displayName;
  bool _analyzing = false;
  bool _updating = false;

  Future<void> _editName() async {
    final controller = TextEditingController(text: _displayName);
    final name = await showDialog<String>(context: context, builder: (context) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: const Text('الاسم الظاهر'), content: TextField(controller: controller, maxLength: 80, decoration: const InputDecoration(hintText: 'اسمك الذي يظهر للآخرين')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('حفظ'))])));
    controller.dispose();
    if (name == null || name.length < 2) return;
    setState(() => _updating = true);
    try {
      await widget.api.updateProfile(name);
      if (mounted) { setState(() => _displayName = name); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الاسم على حسابك.'))); }
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally { if (mounted) setState(() => _updating = false); }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.user.publicUrl));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ رابطك الشخصي.')));
  }

  Future<void> _analyze() async {
    final approved = await showDialog<bool>(context: context, builder: (context) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
      title: const Text('تحليل الشخصية'),
      content: const Text('سيُرسل نص الرسائل المؤهلة بعد تنقيحها إلى مزوّد الذكاء الاصطناعي الذي أعدّه الموقع. قد يستهلك التحليل من حصتك وقد يترتب على مالك الموقع تكلفة مزوّد. هل توافق على المتابعة؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ليس الآن')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('أوافق وأتابع'))],
    )));
    if (approved != true) return;
    setState(() => _analyzing = true);
    try {
      final data = await widget.api.analyzePersonality();
      if (!mounted) return;
      await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (context) => _AnalysisSheet(result: Map<String, dynamic>.from(data['result'] as Map? ?? {})));
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message), duration: const Duration(seconds: 5)));
    } finally { if (mounted) setState(() => _analyzing = false); }
  }

  Future<void> _confirmLogout() async {
    final approved = await showDialog<bool>(context: context, builder: (context) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: const Text('تسجيل الخروج؟'), content: const Text('ستحتاج إلى كلمة مرورك للدخول مجددًا.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسجيل الخروج'))])));
    if (approved == true) await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('حسابي')),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        CircleAvatar(radius: 38, backgroundColor: SarehnyColors.primarySoft, foregroundImage: widget.user.avatarUrl == null ? null : NetworkImage(widget.user.avatarUrl!), child: widget.user.avatarUrl == null ? Text(_displayName.isEmpty ? 'ص' : String.fromCharCode(_displayName.runes.first), style: const TextStyle(fontSize: 25, color: SarehnyColors.primary, fontWeight: FontWeight.w800)) : null),
        const SizedBox(height: 12), Text(_displayName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4), Text('@${widget.user.username}', textDirection: TextDirection.ltr, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: _updating ? null : _editName, icon: _updating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.edit_outlined), label: const Text('تعديل الاسم الظاهر')),
      ]))),
      const SizedBox(height: 16),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.link_rounded, color: SarehnyColors.primary), title: const Text('رابطك الشخصي'), subtitle: Text(widget.user.publicUrl, textDirection: TextDirection.ltr, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: IconButton(tooltip: 'نسخ الرابط', onPressed: _copyLink, icon: const Icon(Icons.copy_rounded))),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(leading: const Icon(Icons.mail_outline_rounded, color: SarehnyColors.primary), title: const Text('البريد الإلكتروني'), subtitle: Text(widget.user.email, textDirection: TextDirection.ltr)),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(leading: const Icon(Icons.workspace_premium_outlined, color: SarehnyColors.primary), title: const Text('تحليل المرسل'), subtitle: Text(widget.user.insightsEnabled ? 'مفعّل وفق صلاحيات الموقع' : 'غير مفعّل حاليًا'), dense: true),
      ])),
      const SizedBox(height: 16),
      Card(child: ListTile(leading: const Icon(Icons.auto_awesome_outlined, color: SarehnyColors.primary), title: const Text('تحليل الشخصية'), subtitle: const Text('وفق ميزات وحصص الموقع الحالية'), trailing: _analyzing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_left_rounded), onTap: _analyzing ? null : _analyze)),
      const SizedBox(height: 16),
      Card(child: ListTile(leading: const Icon(Icons.notifications_none_rounded, color: SarehnyColors.muted), title: const Text('إشعارات الرسائل'), subtitle: const Text('إعداد Firebase مطلوب قبل تفعيل Push Android'), trailing: const Icon(Icons.info_outline_rounded), onTap: () => showDialog<void>(context: context, builder: (context) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: const Text('إعداد الإشعارات'), content: const Text('الموقع يدعم Web Push فقط. إشعارات Android الأصلية تحتاج مشروع Firebase ومفتاح إرسال آمن وجدولًا لتسجيل الأجهزة؛ لم تُفعّل دون إعداداتك أو ترحيل قاعدة بيانات.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))]))))),
      const SizedBox(height: 22), OutlinedButton.icon(onPressed: _confirmLogout, icon: const Icon(Icons.logout_rounded), label: const Text('تسجيل الخروج')),
    ]),
  ));
}

class _AnalysisSheet extends StatelessWidget {
  const _AnalysisSheet({required this.result});
  final Map<String, dynamic> result;
  @override
  Widget build(BuildContext context) {
    List<String> values(String key) => (result[key] as List<dynamic>? ?? []).map((item) => item.toString()).toList();
    final sections = <(String, List<String>)>[( 'نقاط القوة', values('strengths')), ('سمات متكررة', values('repeated_traits')), ('مجالات للتطوير', values('improvements'))];
    return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 28), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(result['personality_title'] as String? ?? 'ملامح شخصيتك', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8), Text('النتيجة: ${result['score'] ?? '—'} / 100', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: SarehnyColors.primary)),
      const SizedBox(height: 16), Text(result['summary'] as String? ?? result['impression'] as String? ?? '', style: Theme.of(context).textTheme.bodyLarge),
      for (final section in sections) if (section.$2.isNotEmpty) ...[const SizedBox(height: 18), Text(section.$1, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8), for (final item in section.$2) Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.circle, size: 7, color: SarehnyColors.primary), const SizedBox(width: 9), Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium))]))],
      if (result['advice'] is String && (result['advice'] as String).isNotEmpty) ...[const SizedBox(height: 16), Text('نصيحة', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), Text(result['advice'] as String, style: Theme.of(context).textTheme.bodyMedium)],
      const SizedBox(height: 18), Text('تحليل آلي للتأمل فقط، وليس تشخيصًا نفسيًا.', style: Theme.of(context).textTheme.bodySmall),
    ])));
  }
}
