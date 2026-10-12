import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../app_theme.dart';
import '../models.dart';
import '../native_platform.dart';

class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({super.key, required this.api, required this.message});

  final ApiClient api;
  final InboxMessage message;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  Timer? _pollTimer;
  bool _busy = false;
  bool _playing = false;
  int _positionMs = 0;
  int _durationMs = 0;
  String? _error;

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(NativeVoicePlayback.stop(widget.message.id).catchError((_) {}));
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = await NativeVoicePlayback.state();
      final activeId = (state?['messageId'] as num?)?.toInt();
      if (activeId == widget.message.id && state?['prepared'] == true) {
        if (state?['isPlaying'] == true) {
          await NativeVoicePlayback.pause(widget.message.id);
        } else {
          await NativeVoicePlayback.resume(widget.message.id);
        }
      } else {
        final request = await widget.api.voicePlaybackRequest(widget.message.id);
        await NativeVoicePlayback.play(
          messageId: widget.message.id,
          url: request.uri.toString(),
          origin: request.origin,
          cookie: request.cookie,
        );
      }
      await _refreshState();
      _pollTimer ??= Timer.periodic(const Duration(milliseconds: 450), (_) {
        unawaited(_refreshState());
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? 'تعذّر تشغيل الرسالة الصوتية.');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تشغيل الرسالة الصوتية على هذا الجهاز.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshState() async {
    try {
      final state = await NativeVoicePlayback.state();
      if (!mounted) return;
      if ((state?['messageId'] as num?)?.toInt() != widget.message.id) {
        setState(() => _playing = false);
        _pollTimer?.cancel();
        _pollTimer = null;
        return;
      }
      final position = (state?['positionMs'] as num?)?.toInt() ?? 0;
      final duration = (state?['durationMs'] as num?)?.toInt() ?? 0;
      final playing = state?['isPlaying'] == true;
      setState(() {
        _playing = playing;
        _positionMs = position;
        _durationMs = duration;
        _error = state?['error'] as String?;
      });
      if (!playing && duration > 0 && position >= duration) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    } on PlatformException {
      if (_pollTimer != null) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    }
  }

  Future<void> _seek(double value) async {
    try {
      await NativeVoicePlayback.seek(widget.message.id, value.round());
      await _refreshState();
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? 'تعذّر تغيير موضع التشغيل.');
    }
  }

  String _timeLabel(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<SarehnyPalette>()!;
    final duration = _durationMs > 0 ? _durationMs : (widget.message.audioSeconds ?? 0) * 1000;
    final position = duration == 0 ? 0.0 : _positionMs.clamp(0, duration).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton.filledTonal(
            tooltip: _playing ? 'إيقاف مؤقت' : 'تشغيل الرسالة الصوتية',
            onPressed: _busy ? null : _togglePlayback,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
          const SizedBox(width: 8),
          Icon(Icons.graphic_eq_rounded, color: palette.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'رسالة صوتية',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            _durationMs > 0 ? _timeLabel(_positionMs) : (widget.message.audioSeconds == null ? '--:--' : _timeLabel(duration)),
            textDirection: TextDirection.ltr,
            style: theme.textTheme.bodySmall,
          ),
        ]),
        Slider(
          min: 0,
          max: duration > 0 ? duration.toDouble() : 1,
          value: duration > 0 ? position : 0,
          onChanged: duration > 0 && _durationMs > 0 ? (value) => setState(() => _positionMs = value.round()) : null,
          onChangeEnd: duration > 0 && _durationMs > 0 ? _seek : null,
          semanticFormatterCallback: (value) => 'موضع التشغيل ${_timeLabel(value.round())}',
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ),
      ]),
    );
  }
}
