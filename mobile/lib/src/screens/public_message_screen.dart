import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../app_theme.dart';
import '../native_platform.dart';

class PublicMessageScreen extends StatefulWidget {
  const PublicMessageScreen({super.key, required this.api, this.initialUsername, this.isActive = true});
  final ApiClient api;
  final String? initialUsername;
  final bool isActive;
  @override
  State<PublicMessageScreen> createState() => _PublicMessageScreenState();
}

class _PublicMessageScreenState extends State<PublicMessageScreen> with WidgetsBindingObserver {
  final _username = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  bool _question = false;
  String? _error;
  Map<String, dynamic>? _profile;
  Uint8List? _voiceBytes;
  int _voiceSeconds = 0;
  int _recordingSeconds = 0;
  bool _recording = false;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _username.text = widget.initialUsername ?? '';
    if (_username.text.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    if (_recording) unawaited(NativeVoiceRecording.cancel());
    _username.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PublicMessageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive && _recording) {
      unawaited(_cancelVoiceRecording());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_recording && (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.detached)) {
      _recordingTimer?.cancel();
      unawaited(NativeVoiceRecording.cancel());
      if (mounted) setState(() => _recording = false);
    }
  }

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

  Future<void> _startVoiceRecording() async {
    if (_question || _profile == null || _busy) return;
    setState(() { _busy = true; _error = null; _voiceBytes = null; _voiceSeconds = 0; });
    try {
      await NativeVoicePlayback.stopAll().catchError((_) {});
      await NativeVoiceRecording.start();
      if (!mounted || !widget.isActive) {
        await NativeVoiceRecording.cancel();
        return;
      }
      setState(() { _recording = true; _recordingSeconds = 0; });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_recording) { timer.cancel(); return; }
        final next = _recordingSeconds + 1;
        setState(() => _recordingSeconds = next);
        if (next >= 120) unawaited(_stopVoiceRecording());
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? 'تعذّر بدء التسجيل الصوتي.');
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر بدء التسجيل الصوتي على هذا الجهاز.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopVoiceRecording() async {
    if (!_recording || _busy) return;
    _recordingTimer?.cancel();
    setState(() { _busy = true; _error = null; });
    try {
      final recording = await NativeVoiceRecording.stop();
      final value = recording?['bytes'];
      final bytes = value is Uint8List ? value : value is List<int> ? Uint8List.fromList(value) : null;
      final seconds = recording?['durationSeconds'];
      if (bytes == null || bytes.isEmpty || seconds is! int) {
        throw const ApiException('لم يتم حفظ التسجيل. أعد المحاولة.');
      }
      if (mounted) setState(() { _voiceBytes = bytes; _voiceSeconds = seconds; _recording = false; });
    } on PlatformException catch (error) {
      if (mounted) setState(() { _recording = false; _error = error.message ?? 'تعذّر حفظ التسجيل. حاول تسجيل ثانية واحدة على الأقل.'; });
    } on ApiException catch (error) {
      if (mounted) setState(() { _recording = false; _error = error.message; });
    } catch (_) {
      if (mounted) setState(() { _recording = false; _error = 'تعذّر حفظ التسجيل. حاول تسجيل ثانية واحدة على الأقل.'; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    if (_recording) await NativeVoiceRecording.cancel().catchError((_) {});
    if (mounted) setState(() { _recording = false; _voiceBytes = null; _voiceSeconds = 0; _recordingSeconds = 0; });
  }

  Future<void> _sendVoice() async {
    final bytes = _voiceBytes;
    if (_profile == null || bytes == null || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.sendPublicVoiceMessage(
        username: _username.text.trim().replaceFirst(RegExp(r'^@'), ''),
        bytes: bytes,
        durationSeconds: _voiceSeconds,
        body: _message.text.trim(),
      );
      if (mounted) setState(() { _sent = true; _voiceBytes = null; });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatDuration(int seconds) => '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('إرسال رسالة مجهولة')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
      Text('كلمة صادقة،\nبلا اسم.', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text('اكتب اسم حساب صراحة لإرسال رسالة خاصة أو سؤال مجهول.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).extension<SarehnyPalette>()!.muted)),
      const SizedBox(height: 22),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: TextField(controller: _username, textDirection: TextDirection.ltr, textAlign: TextAlign.left, onSubmitted: (_) => _lookup(), onChanged: (_) => setState(() { _profile = null; _sent = false; _error = null; }), enabled: !_busy && !_recording && _voiceBytes == null, decoration: const InputDecoration(prefixText: '@', hintText: 'username', labelText: 'حساب المستلم'))),
        const SizedBox(width: 9),
        SizedBox(height: 56, child: FilledButton.tonal(onPressed: _busy || _recording || _voiceBytes != null ? null : _lookup, child: const Icon(Icons.arrow_forward_rounded))),
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
        SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('رسالة خاصة'), icon: Icon(Icons.lock_outline_rounded)), ButtonSegment(value: true, label: Text('سؤال'), icon: Icon(Icons.help_outline_rounded))], selected: {_question}, onSelectionChanged: _voiceBytes != null || _recording ? null : (selection) => setState(() => _question = selection.first)),
        if (!_question) ...[
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('رسالة صوتية', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('تُسجّل على جهازك وتُرسل بعد موافقتك. الحد الأقصى دقيقتان و٦ ميجابايت.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).extension<SarehnyPalette>()!.muted)),
            const SizedBox(height: 10),
            if (_recording) Row(children: [
              Icon(Icons.fiber_manual_record_rounded, color: Theme.of(context).colorScheme.error, size: 17),
              const SizedBox(width: 8),
              Expanded(child: Text('جارٍ التسجيل · ${_formatDuration(_recordingSeconds)}', style: Theme.of(context).textTheme.bodyMedium)),
              OutlinedButton.icon(onPressed: _busy ? null : _stopVoiceRecording, icon: const Icon(Icons.stop_rounded), label: const Text('إيقاف')),
              const SizedBox(width: 6),
              IconButton(tooltip: 'إلغاء التسجيل', onPressed: _busy ? null : _cancelVoiceRecording, icon: const Icon(Icons.delete_outline_rounded)),
            ]) else if (_voiceBytes != null) Row(children: [
              Icon(Icons.mic_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('التسجيل جاهز · ${_formatDuration(_voiceSeconds)}', style: Theme.of(context).textTheme.bodyMedium)),
              IconButton(tooltip: 'حذف التسجيل', onPressed: _busy ? null : _cancelVoiceRecording, icon: const Icon(Icons.delete_outline_rounded)),
            ]) else Align(alignment: AlignmentDirectional.centerStart, child: OutlinedButton.icon(
              onPressed: _busy ? null : _startVoiceRecording,
              icon: const Icon(Icons.mic_none_rounded),
              label: const Text('ابدأ التسجيل'),
            )),
          ]))),
        ],
        const SizedBox(height: 14),
        TextField(controller: _message, minLines: 5, maxLines: 9, maxLength: 1000, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'اكتب ما تريد قوله بصدق أو أضف نصًا مع التسجيل...', alignLabelWithHint: true)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Theme.of(context).extension<SarehnyPalette>()!.primarySoft, borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(Icons.visibility_off_outlined, size: 18, color: Theme.of(context).extension<SarehnyPalette>()!.primary), const SizedBox(width: 9), Expanded(child: Text('لن يظهر اسمك لصاحب الحساب. أرسل باحترام.', style: TextStyle(color: Theme.of(context).extension<SarehnyPalette>()!.ink, fontSize: 12, height: 1.5)))])),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).extension<SarehnyPalette>()!.danger))),
        if (_sent) Padding(padding: const EdgeInsets.only(top: 12), child: Text('وصلت رسالتك إلى صندوقه.', style: TextStyle(color: Theme.of(context).extension<SarehnyPalette>()!.success, fontWeight: FontWeight.w700))),
        const SizedBox(height: 15),
        FilledButton.icon(
          onPressed: _busy || _sent || _recording || (_voiceBytes == null && _message.text.trim().length < 2)
              ? null
              : (_voiceBytes != null ? _sendVoice : _send),
          icon: Icon(_voiceBytes != null ? Icons.mic_none_rounded : Icons.send_rounded),
          label: Text(_sent ? 'تم الإرسال' : _voiceBytes != null ? 'إرسال الرسالة الصوتية' : 'إرسال دون اسم'),
        ),
        if (_sent) TextButton(onPressed: () => setState(() { _sent = false; _message.clear(); _voiceSeconds = 0; }), child: const Text('إرسال رسالة أخرى')),
      ],
      if (_error != null && _profile == null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: TextStyle(color: Theme.of(context).extension<SarehnyPalette>()!.danger))),
    ])),
  ));
}
