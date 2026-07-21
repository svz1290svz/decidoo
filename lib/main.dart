import 'package:flutter/material.dart';

import 'src/auth/auth_gate.dart';
import 'src/auth/auth_session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionController = AuthSessionController();
  await sessionController.restore();

  runApp(AuthGate(controller: sessionController));
}
