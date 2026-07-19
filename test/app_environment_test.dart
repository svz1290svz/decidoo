import 'package:decidoo/src/core/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('uses safe development defaults', () {
      final config = AppConfig.fromEnvironment();

      expect(config.environment, AppEnvironment.development);
      expect(config.apiBaseUrl, Uri.parse('https://api.decidoo.app'));
      expect(config.enableAnalytics, isFalse);
      expect(config.enableCrashReporting, isFalse);
      expect(config.enablePayments, isFalse);
    });

    test('rejects an unknown environment instead of silently downgrading', () {
      expect(
        () => AppConfig.parse(
          environmentName: 'prodution',
          apiUrl: 'https://api.decidoo.app',
        ),
        throwsFormatException,
      );
    });

    test('requires HTTPS in production', () {
      expect(
        () => AppConfig.parse(
          environmentName: 'production',
          apiUrl: 'http://api.decidoo.app',
        ),
        throwsFormatException,
      );
    });

    test('accepts explicit production feature flags', () {
      final config = AppConfig.parse(
        environmentName: 'production',
        apiUrl: 'https://api.decidoo.app',
        enableAnalytics: true,
        enableCrashReporting: true,
        enablePayments: true,
      );

      expect(config.environment, AppEnvironment.production);
      expect(config.enableAnalytics, isTrue);
      expect(config.enableCrashReporting, isTrue);
      expect(config.enablePayments, isTrue);
    });
  });
}
