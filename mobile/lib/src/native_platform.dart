import 'package:flutter/services.dart';

class NativeImagePicker {
  NativeImagePicker._();

  static const _platform = MethodChannel('com.sarehny/platform');

  static Future<Map<String, Object?>?> pickImage() =>
      _platform.invokeMapMethod<String, Object?>('pickImage');
}

