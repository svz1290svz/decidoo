enum AppEnvironment { development, staging, production }

final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableAnalytics,
    required this.enableCrashReporting,
    required this.enablePayments,
  });

  final AppEnvironment environment;
  final Uri apiBaseUrl;
  final bool enableAnalytics;
  final bool enableCrashReporting;
  final bool enablePayments;

  factory AppConfig.fromEnvironment() {
    return AppConfig.parse(
      environmentName: const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'development',
      ),
      apiUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://api.decidoo.app',
      ),
      enableAnalytics: const bool.fromEnvironment('ENABLE_ANALYTICS'),
      enableCrashReporting:
          const bool.fromEnvironment('ENABLE_CRASH_REPORTING'),
      enablePayments: const bool.fromEnvironment('ENABLE_PAYMENTS'),
    );
  }

  factory AppConfig.parse({
    required String environmentName,
    required String apiUrl,
    bool enableAnalytics = false,
    bool enableCrashReporting = false,
    bool enablePayments = false,
  }) {
    final environment = switch (environmentName) {
      'development' => AppEnvironment.development,
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => throw FormatException('Unsupported APP_ENV: $environmentName'),
    };

    final uri = Uri.tryParse(apiUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const FormatException('API_BASE_URL must be an absolute URL.');
    }
    if (environment == AppEnvironment.production && uri.scheme != 'https') {
      throw const FormatException('Production API_BASE_URL must use HTTPS.');
    }

    return AppConfig(
      environment: environment,
      apiBaseUrl: uri,
      enableAnalytics: enableAnalytics,
      enableCrashReporting: enableCrashReporting,
      enablePayments: enablePayments,
    );
  }
}
