abstract interface class AnalyticsService {
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const {},
  });
}

abstract interface class CrashReporter {
  Future<void> record(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    Map<String, Object?> context = const {},
  });
}

final class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const {},
  }) async {}
}

final class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> record(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    Map<String, Object?> context = const {},
  }) async {}
}
