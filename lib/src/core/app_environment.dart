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
    const environmentName = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const apiUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.decidoo.app',
    );

    final environment = switch (environmentName) {
      'production' => AppEnvironment.production,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.development,
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
      enableAnalytics: const bool.fromEnvironment('ENABLE_ANALYTICS'),
      enableCrashReporting: const bool.fromEnvironment(
        'ENABLE_CRASH_REPORTING',
      ),
      enablePayments: const bool.fromEnvironment('ENABLE_PAYMENTS'),
    );
  }
}
