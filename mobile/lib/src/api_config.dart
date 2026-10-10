class ApiConfig {
  const ApiConfig._();

  static const _productionApiBaseUrl = 'https://sarehny.com/api/v1/';
  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    final configured = _configuredApiBaseUrl.trim();
    return configured.isEmpty ? _productionApiBaseUrl : configured;
  }

  static bool get isConfigured => apiBaseUrl.trim().isNotEmpty;
}
