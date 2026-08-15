import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'src/auth/auth_session_controller.dart';
import 'src/observability/error_reporter.dart';
import 'src/services/firebase_push_service.dart';
import 'src/store_ready_gate.dart';

void main() {
  final reporter = ErrorReporter();

  runZonedGuarded(() {
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
    final pushService = FirebasePushService(sessionController);

    // Render the application before touching secure storage, networking or
    // Firebase. External service failures must never prevent first paint.
    runApp(
      PushNotificationHost(
        service: pushService,
        child: StoreReadyGate(controller: sessionController),
      ),
    );

    unawaited(_bootstrap(sessionController, pushService, reporter));
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

Future<void> _bootstrap(
  AuthSessionController sessionController,
  FirebasePushService pushService,
  ErrorReporter reporter,
) async {
  try {
    await sessionController.restore();
  } catch (error, stackTrace) {
    unawaited(
      reporter.record(
        error,
        stackTrace,
        fatal: false,
        source: 'session_bootstrap',
      ),
    );
  }

  try {
    await pushService.initialize();
  } catch (error, stackTrace) {
    unawaited(
      reporter.record(
        error,
        stackTrace,
        fatal: false,
        source: 'push_bootstrap',
      ),
    );
  }
}
