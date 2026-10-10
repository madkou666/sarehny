class ApiConfig {
  const ApiConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static bool get isConfigured => apiBaseUrl.trim().isNotEmpty;
}
