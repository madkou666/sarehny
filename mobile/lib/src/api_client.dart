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
      validateStatus: (status) => status != null && status < 500,
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

  static String _normalizeBaseUrl(String value) => value.endsWith('/') ? value : '$value/';

  final String baseUrl;
  final FlutterSecureStorage _storage;
  late final Dio _dio;
  String? _csrf;

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

  Future<Map<String, dynamic>> inbox({String filter = 'all', int page = 1, int limit = 20}) =>
      _request('GET', 'inbox', query: {'filter': filter, 'page': page, 'limit': limit});

  Future<void> messageAction(int id, String action, {Map<String, String> fields = const {}}) async =>
      _post('messages/$id/$action', fields);

  Future<void> updateProfile(String name) async => _post('account/profile', {'name': name});
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

  Future<Map<String, dynamic>> _request(String method, String path, {Map<String, dynamic>? query, Map<String, String>? fields}) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        'index.php',
        queryParameters: {'r': path, ...?query},
        data: fields == null ? null : FormData.fromMap(fields),
        options: Options(method: method),
      );
      final data = response.data ?? <String, dynamic>{};
      if (response.statusCode == null || response.statusCode! >= 400 || data['ok'] != true) {
        if (response.statusCode == 419) _csrf = data['csrf'] as String?;
        throw ApiException(data['message'] as String? ?? 'تعذّر الاتصال بالخادم.', statusCode: response.statusCode);
      }
      if (data.containsKey('csrf')) _csrf = data['csrf'] as String?;
      return data;
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map<String, dynamic> && body['message'] is String) {
        throw ApiException(body['message'] as String, statusCode: error.response?.statusCode);
      }
      throw const ApiException('تحقق من اتصال الإنترنت وحاول مجددًا.');
    }
  }
}
