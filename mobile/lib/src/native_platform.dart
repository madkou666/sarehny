import 'package:flutter/services.dart';

class NativeImagePicker {
  NativeImagePicker._();

  static const _platform = MethodChannel('com.sarehny/platform');

  static Future<Map<String, Object?>?> pickImage() =>
      _platform.invokeMapMethod<String, Object?>('pickImage');
}

class NativeVoiceRecording {
  NativeVoiceRecording._();

  static const _platform = MethodChannel('com.sarehny/platform');

  static Future<void> start() => _platform.invokeMethod<void>('startVoiceRecording');

  static Future<Map<String, Object?>?> stop() =>
      _platform.invokeMapMethod<String, Object?>('stopVoiceRecording');

  static Future<void> cancel() =>
      _platform.invokeMethod<void>('cancelVoiceRecording');
}

class NativeVoicePlayback {
  NativeVoicePlayback._();

  static const _platform = MethodChannel('com.sarehny/platform');

  static Future<void> play({
    required int messageId,
    required String url,
    required String origin,
    required String cookie,
  }) => _platform.invokeMethod<void>('playVoice', {
        'messageId': messageId,
        'url': url,
        'origin': origin,
        'cookie': cookie,
      });

  static Future<void> pause(int messageId) =>
      _platform.invokeMethod<void>('pauseVoice', {'messageId': messageId});

  static Future<void> resume(int messageId) =>
      _platform.invokeMethod<void>('resumeVoice', {'messageId': messageId});

  static Future<void> seek(int messageId, int positionMs) =>
      _platform.invokeMethod<void>('seekVoice', {
        'messageId': messageId,
        'positionMs': positionMs,
      });

  static Future<Map<String, Object?>?> state() =>
      _platform.invokeMapMethod<String, Object?>('voiceState');

  static Future<void> stop(int messageId) =>
      _platform.invokeMethod<void>('stopVoice', {'messageId': messageId});

  static Future<void> stopAll() => _platform.invokeMethod<void>('stopVoice');
}

