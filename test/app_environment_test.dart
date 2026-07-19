import 'package:decidoo/src/core/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses safe development defaults', () {
    final config = AppConfig.fromEnvironment();

    expect(config.environment, AppEnvironment.development);
    expect(config.apiBaseUrl, Uri.parse('https://api.decidoo.app'));
    expect(config.enableAnalytics, isFalse);
    expect(config.enableCrashReporting, isFalse);
    expect(config.enablePayments, isFalse);
  });
}
