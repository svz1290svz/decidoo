import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'src/auth/auth_gate.dart';
import 'src/auth/auth_session_controller.dart';
import 'src/observability/error_reporter.dart';

void main() {
  final reporter = ErrorReporter();

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(
        reporter.record(
          details.exception,
          details.stack ?? StackTrace.current,
          fatal: true,
          source: 'flutter',
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(
        reporter.record(
          error,
          stackTrace,
          fatal: true,
          source: 'platform',
        ),
      );
      return true;
    };

    final sessionController = AuthSessionController();
    await sessionController.restore();

    runApp(AuthGate(controller: sessionController));
  }, (error, stackTrace) {
    unawaited(
      reporter.record(
        error,
        stackTrace,
        fatal: true,
        source: 'zone',
      ),
    );
  });
}
