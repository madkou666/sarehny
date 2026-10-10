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
  late String _username = widget.user.username;
  late String _email = widget.user.email;
  late String _publicUrl = widget.user.publicUrl;
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

  Future<void> _editUsername() async {
    final controller = TextEditingController(text: _username);
    final username = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير اسم المستخدم'),
          content: TextField(
            controller: controller,
            maxLength: 30,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(prefixText: '@ ', hintText: 'sara_99'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim().toLowerCase()), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (username == null || username == _username) return;
    setState(() => _updating = true);
    try {
      final updated = await widget.api.updateUsername(username);
      if (mounted) {
        setState(() {
          _username = updated.username;
          _publicUrl = updated.publicUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير اسم المستخدم والرابط الشخصي.')));
      }
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _editEmail() async {
    final emailController = TextEditingController(text: _email);
    final passwordController = TextEditingController();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير البريد الإلكتروني'),
          scrollable: true,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: emailController, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'البريد الجديد')),
            const SizedBox(height: 12),
            TextField(controller: passwordController, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'كلمة المرور الحالية')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, {'email': emailController.text.trim(), 'password': passwordController.text}), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    emailController.dispose();
    passwordController.dispose();
    if (values == null) return;
    setState(() => _updating = true);
    try {
      await widget.api.updateEmail(values['email']!, values['password']!);
      if (mounted) {
        setState(() => _email = values['email']!);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث البريد الإلكتروني.')));
      }
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          scrollable: true,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: currentController, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'كلمة المرور الحالية')),
            const SizedBox(height: 10),
            TextField(controller: newController, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
            const SizedBox(height: 10),
            TextField(controller: confirmController, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور الجديدة')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, {'current': currentController.text, 'new': newController.text, 'confirm': confirmController.text}), child: const Text('تغيير')),
          ],
        ),
      ),
    );
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
    if (!mounted || values == null) return;
    if (values['new']!.length < 8 || values['new'] != values['confirm']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تأكد من تطابق كلمة المرور الجديدة وأنها ٨ أحرف على الأقل.')));
      return;
    }
    setState(() => _updating = true);
    try {
      await widget.api.updatePassword(values['current']!, values['new']!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور.')));
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _deleteAccount() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الحساب نهائيًا؟'),
          scrollable: true,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('سيُحذف حسابك ورسائلك المرتبطة به، ولا يمكن التراجع عن ذلك. اكتب اسم المستخدم وكلمة المرور للتأكيد.'),
            const SizedBox(height: 12),
            TextField(controller: usernameController, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
            const SizedBox(height: 10),
            TextField(controller: passwordController, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'كلمة المرور')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, {'username': usernameController.text.trim(), 'password': passwordController.text}), style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: const Text('حذف الحساب')),
          ],
        ),
      ),
    );
    usernameController.dispose();
    passwordController.dispose();
    if (values == null) return;
    setState(() => _updating = true);
    try {
      await widget.api.deleteAccount(values['password']!, values['username']!);
      if (mounted) await widget.onLogout();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _openAdmin() async {
    try {
      await const MethodChannel('com.sarehny/external_browser').invokeMethod<void>(
        'open',
        {'url': widget.api.adminUrl.toString()},
      );
    } on PlatformException {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر فتح لوحة الإدارة في المتصفح.')));
    } on MissingPluginException {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فتح المتصفح غير متاح على هذا الجهاز.')));
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _publicUrl));
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
        CircleAvatar(radius: 38, backgroundColor: Theme.of(context).extension<SarehnyPalette>()!.primarySoft, foregroundImage: widget.user.avatarUrl == null ? null : NetworkImage(widget.user.avatarUrl!), child: widget.user.avatarUrl == null ? Text(_displayName.isEmpty ? 'ص' : String.fromCharCode(_displayName.runes.first), style: TextStyle(fontSize: 25, color: Theme.of(context).extension<SarehnyPalette>()!.primary, fontWeight: FontWeight.w800)) : null),
        const SizedBox(height: 12), Text(_displayName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4), Text('@$_username', textDirection: TextDirection.ltr, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: _updating ? null : _editName, icon: _updating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.edit_outlined), label: const Text('تعديل الاسم الظاهر')),
      ]))),
      const SizedBox(height: 16),
      Card(child: Column(children: [
        ListTile(leading: Icon(Icons.link_rounded, color: Theme.of(context).extension<SarehnyPalette>()!.primary), title: const Text('رابطك الشخصي'), subtitle: Text(_publicUrl, textDirection: TextDirection.ltr, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: IconButton(tooltip: 'نسخ الرابط', onPressed: _copyLink, icon: const Icon(Icons.copy_rounded))),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(leading: Icon(Icons.mail_outline_rounded, color: Theme.of(context).extension<SarehnyPalette>()!.primary), title: const Text('البريد الإلكتروني'), subtitle: Text(_email, textDirection: TextDirection.ltr)),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(leading: Icon(Icons.workspace_premium_outlined, color: Theme.of(context).extension<SarehnyPalette>()!.primary), title: const Text('تحليل المرسل'), subtitle: Text(widget.user.insightsEnabled ? 'مفعّل وفق صلاحيات الموقع' : 'غير مفعّل حاليًا'), dense: true),
      ])),
      const SizedBox(height: 16),
      Card(child: Column(children: [
        ListTile(leading: Icon(Icons.alternate_email_rounded, color: Theme.of(context).extension<SarehnyPalette>()!.primary), title: const Text('اسم المستخدم'), subtitle: Text('@$_username', textDirection: TextDirection.ltr), trailing: const Icon(Icons.chevron_left_rounded), onTap: _updating ? null : _editUsername),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(leading: Icon(Icons.mail_outline_rounded, color: Theme.of(context).extension<SarehnyPalette>()!.primary), title: const Text('تغيير البريد الإلكتروني'), subtitle: const Text('يتطلب كلمة المرور الحالية'), trailing: const Icon(Icons.chevron_left_rounded), onTap: _updating ? null : _editEmail),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(leading: Icon(Icons.key_rounded, color: Theme.of(context).extension<SarehnyPalette>()!.primary), title: const Text('تغيير كلمة المرور'), trailing: const Icon(Icons.chevron_left_rounded), onTap: _updating ? null : _changePassword),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error), title: Text('حذف الحساب نهائيًا', style: TextStyle(color: Theme.of(context).colorScheme.error)), subtitle: const Text('يتطلب تأكيد اسم المستخدم وكلمة المرور'), onTap: _updating ? null : _deleteAccount),
        if (widget.user.isAdmin) ...[
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(leading: Icon(Icons.admin_panel_settings_outlined, color: Theme.of(context).extension<SarehnyPalette>()!.primary), title: const Text('لوحة الإدارة'), subtitle: const Text('تُفتح في المتصفح وتستخدم تسجيل الموقع المعتاد'), trailing: const Icon(Icons.open_in_new_rounded), onTap: _openAdmin),
        ],
      ])),
      const SizedBox(height: 16),
      Card(child: ListTile(leading: Icon(Icons.auto_awesome_outlined, color: Theme.of(context).extension<SarehnyPalette>()!.primary), title: const Text('تحليل الشخصية'), subtitle: const Text('وفق ميزات وحصص الموقع الحالية'), trailing: _analyzing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_left_rounded), onTap: _analyzing ? null : _analyze)),
      const SizedBox(height: 16),
      Card(child: ListTile(leading: Icon(Icons.notifications_none_rounded, color: Theme.of(context).extension<SarehnyPalette>()!.muted), title: const Text('إشعارات الرسائل'), subtitle: const Text('إعداد Firebase مطلوب قبل تفعيل Push Android'), trailing: const Icon(Icons.info_outline_rounded), onTap: () => showDialog<void>(context: context, builder: (context) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: const Text('إعداد الإشعارات'), content: const Text('الموقع يدعم Web Push فقط. إشعارات Android الأصلية تحتاج مشروع Firebase ومفتاح إرسال آمن وجدولًا لتسجيل الأجهزة؛ لم تُفعّل دون إعداداتك أو ترحيل قاعدة بيانات.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))]))))),
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
      const SizedBox(height: 8), Text('النتيجة: ${result['score'] ?? '—'} / 100', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).extension<SarehnyPalette>()!.primary)),
      const SizedBox(height: 16), Text(result['summary'] as String? ?? result['impression'] as String? ?? '', style: Theme.of(context).textTheme.bodyLarge),
      for (final section in sections) if (section.$2.isNotEmpty) ...[const SizedBox(height: 18), Text(section.$1, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8), for (final item in section.$2) Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.circle, size: 7, color: Theme.of(context).extension<SarehnyPalette>()!.primary), const SizedBox(width: 9), Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium))]))],
      if (result['advice'] is String && (result['advice'] as String).isNotEmpty) ...[const SizedBox(height: 16), Text('نصيحة', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), Text(result['advice'] as String, style: Theme.of(context).textTheme.bodyMedium)],
      const SizedBox(height: 18), Text('تحليل آلي للتأمل فقط، وليس تشخيصًا نفسيًا.', style: Theme.of(context).textTheme.bodySmall),
    ])));
  }
}
