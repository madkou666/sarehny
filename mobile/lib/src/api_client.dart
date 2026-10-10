import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = _normalizeBaseUrl(baseUrl ?? ApiConfig.apiBaseUrl),
        _storage = const FlutterSecureStorage() {
    _dio = Dio(BaseOptions(
      baseUrl: this.baseUrl,
      connectTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
      validateStatus: (status) => status != null,
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookie = await _storage.read(key: 'sarehny_php_session');
        if (cookie != null && cookie.isNotEmpty) options.headers['Cookie'] = cookie;
        handler.next(options);
      },
      onResponse: (response, handler) async {
        final values = response.headers.map['set-cookie'] ?? const <String>[];
        for (final value in values) {
          final cookie = value.split(';').first.trim();
          if (cookie.startsWith('PHPSESSID=')) await _storage.write(key: 'sarehny_php_session', value: cookie);
        }
        handler.next(response);
      },
    ));
  }

  static String _normalizeBaseUrl(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';
    return normalized.endsWith('/') ? normalized : '$normalized/';
  }

  final String baseUrl;
  Uri get siteOrigin => Uri.parse(baseUrl).resolve('../../');
  Uri get adminUrl => sitePage('admin.php');

  Uri sitePage(String path, {Map<String, String>? queryParameters}) {
    if (baseUrl.isEmpty || !RegExp(r'^[a-zA-Z0-9_-]+(?:\.php)?$').hasMatch(path)) {
      throw const ApiException('رابط صفحة الموقع غير صالح أو أن عنوان API غير مهيأ.');
    }
    return siteOrigin.resolve(path).replace(queryParameters: queryParameters);
  }

  final FlutterSecureStorage _storage;
  late final Dio _dio;
  String? _csrf;
  void Function()? onUnauthorized;

  Future<Map<String, dynamic>> session() async {
    final data = await _request('GET', 'session');
    _csrf = data['csrf'] as String?;
    return data;
  }

  Future<AppUser> login(String identifier, String password) async {
    if (_csrf == null) await session();
    final data = await _post('auth/login', {'identifier': identifier.trim(), 'password': password});
    _csrf = data['csrf'] as String? ?? _csrf;
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> register({required String name, required String username, required String email, required String password}) async {
    if (_csrf == null) await session();
    final data = await _post('auth/register', {'name': name, 'username': username, 'email': email, 'password': password});
    _csrf = data['csrf'] as String? ?? _csrf;
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _post('auth/logout', {});
    } finally {
      await _storage.delete(key: 'sarehny_php_session');
      _csrf = null;
    }
  }

  Future<Map<String, dynamic>> appTheme() async {
    try {
      final data = await _request('GET', 'app-theme');
      final theme = data['theme'];
      if (theme is! Map) throw const ApiException('إعدادات المظهر من الخادم غير صالحة.');
      final value = Map<String, dynamic>.from(theme);
      try {
        await _storage.write(key: 'sarehny_app_theme_cache', value: jsonEncode(value));
      } catch (_) {}
      return {'theme': value, 'cached': false};
    } catch (_) {
      final cached = await _storage.read(key: 'sarehny_app_theme_cache');
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached);
          if (decoded is Map) {
            return {'theme': Map<String, dynamic>.from(decoded), 'cached': true};
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> inbox({
    String filter = 'all',
    int page = 1,
    int limit = 20,
    String? beforeCreatedAt,
    int? beforeId,
  }) => _request('GET', 'inbox', query: {
        'filter': filter,
        'page': page,
        'limit': limit,
        if (beforeCreatedAt != null && beforeId != null) 'before_created_at': beforeCreatedAt,
        if (beforeCreatedAt != null && beforeId != null) 'before_id': beforeId,
      });

  Future<void> messageAction(int id, String action, {Map<String, String> fields = const {}}) async =>
      _post('messages/$id/$action', fields);

  Future<AppUser> updateProfile(String name) async {
    final data = await _post('account/profile', {'name': name});
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<String?> readPhpSessionCookie() => _storage.read(key: 'sarehny_php_session');

  Future<void> savePhpSessionCookie(String cookie) async {
    if (!RegExp(r'^PHPSESSID=[A-Za-z0-9,-]{8,256}$').hasMatch(cookie)) {
      throw const ApiException('تعذّر تحديث جلسة الموقع بسبب استجابة غير صالحة.');
    }
    await _storage.write(key: 'sarehny_php_session', value: cookie);
  }

  Future<AppUser> uploadAvatar(Uint8List bytes, {required String fileName}) async {
    if (_csrf == null) await session();
    final data = await _request(
      'POST',
      'account/avatar',
      formData: FormData.fromMap({
        'csrf': _csrf ?? '',
        'avatar': MultipartFile.fromBytes(bytes, filename: fileName),
      }),
    );
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<AppUser> removeAvatar() async {
    final data = await _post('account/avatar/remove', {});
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<AppUser> updateUsername(String username) async {
    final data = await _post('account/username', {'username': username});
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }
  Future<AppUser> updateEmail(String email, String currentPassword) async {
    final data = await _post('account/email', {'email': email, 'current_password': currentPassword});
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }
  Future<void> updatePassword(String currentPassword, String newPassword) async =>
      _post('account/password', {'current_password': currentPassword, 'new_password': newPassword});
  Future<void> deleteAccount(String currentPassword, String username) async {
    await _post('account/delete', {'current_password': currentPassword, 'confirm_username': username});
    await _storage.delete(key: 'sarehny_php_session');
    _csrf = null;
  }
  Future<void> sendPublicMessage(String username, String body, {bool question = false}) async =>
      _post('public-messages', {'username': username, 'body': body, 'kind': question ? 'question' : 'message'});

  Future<Map<String, dynamic>> account() => _request('GET', 'account');
  Future<Map<String, dynamic>> publicProfile(String username) => _request('GET', 'public-profile', query: {'username': username});

  Future<Map<String, dynamic>> analyzePersonality() async {
    if (_csrf == null) await session();
    try {
      final analysisEndpoint = Uri.parse(baseUrl).resolve('/ai_analyze.php').toString();
      final response = await _dio.post<Map<String, dynamic>>(
        analysisEndpoint,
        data: FormData.fromMap({'csrf': _csrf ?? '', 'action': 'analyze', 'consent': '1', 'request_id': DateTime.now().microsecondsSinceEpoch.toString()}),
        options: Options(receiveTimeout: const Duration(seconds: 210)),
      );
      final data = response.data ?? <String, dynamic>{};
      if (response.statusCode == null || response.statusCode! >= 400 || data['ok'] != true) {
        if (response.statusCode == 419) _csrf = data['csrf'] as String?;
        throw ApiException(data['message'] as String? ?? 'تعذّر إكمال التحليل الآن.', statusCode: response.statusCode);
      }
      return data;
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map<String, dynamic> && body['message'] is String) {
        throw ApiException(body['message'] as String, statusCode: error.response?.statusCode);
      }
      throw const ApiException('لم يكتمل التحليل بسبب مشكلة في الاتصال. لم نعد إرسال الطلب تلقائيًا.');
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, String> fields) async {
    if (_csrf == null) await session();
    return _request('POST', path, fields: {'csrf': _csrf ?? '', ...fields});
  }

  Future<Map<String, dynamic>> _request(String method, String path, {Map<String, dynamic>? query, Map<String, String>? fields, FormData? formData}) async {
    if (baseUrl.isEmpty) {
      throw const ApiException('الاتصال بالخادم غير مهيأ. لم يتم إرسال أي طلب API.');
    }
    try {
      final response = await _dio.request<dynamic>(
        'index.php',
        queryParameters: {'r': path, ...?query},
        data: formData ?? (fields == null ? null : FormData.fromMap(fields)),
        options: Options(method: method),
      );
      final payload = response.data;
      final data = payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{};
      if (response.statusCode == null || response.statusCode! >= 400 || data['ok'] != true) {
        if (response.statusCode == 419) _csrf = data['csrf'] as String?;
        if (response.statusCode == 401 && !path.startsWith('auth/')) onUnauthorized?.call();
        final uri = response.requestOptions.uri;
        final fallbackMessage = response.statusCode != null
            ? 'استجابة HTTP ${response.statusCode} من ${uri.origin}${uri.path}. تحقق من نشر واجهة PHP على هذا المسار.'
            : 'استجابة API غير صالحة.';
        throw ApiException(
          data['message'] as String? ?? fallbackMessage,
          statusCode: response.statusCode,
        );
      }
      if (data.containsKey('csrf')) _csrf = data['csrf'] as String?;
      return data;
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map && body['message'] is String) {
        throw ApiException(body['message'] as String, statusCode: error.response?.statusCode);
      }
      final uri = error.requestOptions.uri;
      throw ApiException(
        'تعذّر الاتصال بـ ${uri.origin}${uri.path} عبر HTTPS. تحقق من اتصال الإنترنت وتوفر واجهة API.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
