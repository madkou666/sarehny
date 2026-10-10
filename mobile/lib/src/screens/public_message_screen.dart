import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_theme.dart';

class PublicMessageScreen extends StatefulWidget {
  const PublicMessageScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<PublicMessageScreen> createState() => _PublicMessageScreenState();
}

class _PublicMessageScreenState extends State<PublicMessageScreen> {
  final _username = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  bool _question = false;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void dispose() { _username.dispose(); _message.dispose(); super.dispose(); }

  Future<void> _lookup() async {
    final name = _username.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(name)) { setState(() => _error = 'اكتب اسم مستخدم صالحًا من ٣ إلى ٣٠ حرفًا.'); return; }
    setState(() { _busy = true; _error = null; _profile = null; });
    try {
      final data = await widget.api.publicProfile(name);
      final currentName = _username.text.trim().replaceFirst(RegExp(r'^@'), '');
      if (mounted && currentName.toLowerCase() == name.toLowerCase()) {
        setState(() => _profile = Map<String, dynamic>.from(data['profile'] as Map));
      }
    } on ApiException catch (error) {
      final currentName = _username.text.trim().replaceFirst(RegExp(r'^@'), '');
      if (mounted && currentName.toLowerCase() == name.toLowerCase()) {
        setState(() => _error = error.message);
      }
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _send() async {
    if (_profile == null || _message.text.trim().length < 2) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.sendPublicMessage(_username.text.trim().replaceFirst(RegExp(r'^@'), ''), _message.text.trim(), question: _question);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('إرسال رسالة مجهولة')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
      Text('كلمة صادقة،\nبلا اسم.', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text('اكتب اسم حساب صراحة لإرسال رسالة خاصة أو سؤال مجهول.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).extension<SarehnyPalette>()!.muted)),
      const SizedBox(height: 22),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: TextField(controller: _username, textDirection: TextDirection.ltr, textAlign: TextAlign.left, onSubmitted: (_) => _lookup(), onChanged: (_) => setState(() { _profile = null; _sent = false; _error = null; }), enabled: !_busy, decoration: const InputDecoration(prefixText: '@', hintText: 'username', labelText: 'حساب المستلم'))),
        const SizedBox(width: 9),
        SizedBox(height: 56, child: FilledButton.tonal(onPressed: _busy ? null : _lookup, child: const Icon(Icons.arrow_forward_rounded))),
      ]),
      if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      if (_profile != null) ...[
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Theme.of(context).extension<SarehnyPalette>()!.line)), child: Row(children: [
          CircleAvatar(backgroundColor: Theme.of(context).extension<SarehnyPalette>()!.primarySoft, foregroundImage: _profile!['avatar_url'] == null ? null : NetworkImage(_profile!['avatar_url'] as String), child: _profile!['avatar_url'] == null ? Icon(Icons.person_outline_rounded, color: Theme.of(context).extension<SarehnyPalette>()!.primary) : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_profile!['display_name'] as String? ?? '', style: Theme.of(context).textTheme.titleMedium), Text('@${_profile!['username']}', textDirection: TextDirection.ltr, style: Theme.of(context).textTheme.bodySmall)])),
          if (_profile!['is_verified'] == true)
            Icon(Icons.verified_user_outlined, color: Theme.of(context).extension<SarehnyPalette>()!.success, size: 19),
        ])),
        const SizedBox(height: 14),
        SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('رسالة خاصة'), icon: Icon(Icons.lock_outline_rounded)), ButtonSegment(value: true, label: Text('سؤال'), icon: Icon(Icons.help_outline_rounded))], selected: {_question}, onSelectionChanged: (selection) => setState(() => _question = selection.first)),
        const SizedBox(height: 14),
        TextField(controller: _message, minLines: 5, maxLines: 9, maxLength: 1000, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'اكتب ما تريد قوله بصدق...', alignLabelWithHint: true)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Theme.of(context).extension<SarehnyPalette>()!.primarySoft, borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(Icons.visibility_off_outlined, size: 18, color: Theme.of(context).extension<SarehnyPalette>()!.primary), const SizedBox(width: 9), Expanded(child: Text('لن يظهر اسمك لصاحب الحساب. أرسل باحترام.', style: TextStyle(color: Theme.of(context).extension<SarehnyPalette>()!.ink, fontSize: 12, height: 1.5)))])),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).extension<SarehnyPalette>()!.danger))),
        if (_sent) Padding(padding: const EdgeInsets.only(top: 12), child: Text('وصلت رسالتك إلى صندوقه.', style: TextStyle(color: Theme.of(context).extension<SarehnyPalette>()!.success, fontWeight: FontWeight.w700))),
        const SizedBox(height: 15),
        FilledButton.icon(onPressed: _busy || _sent || _message.text.trim().length < 2 ? null : _send, icon: const Icon(Icons.send_rounded), label: Text(_sent ? 'تم الإرسال' : 'إرسال دون اسم')),
        if (_sent) TextButton(onPressed: () => setState(() { _sent = false; _message.clear(); }), child: const Text('إرسال رسالة أخرى')),
      ],
      if (_error != null && _profile == null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: TextStyle(color: Theme.of(context).extension<SarehnyPalette>()!.danger))),
    ])),
  ));
}
