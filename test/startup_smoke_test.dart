import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:decidoo/src/auth/auth_session_controller.dart';
import 'package:decidoo/src/store_ready_gate.dart';

void main() {
  testWidgets('app renders a first frame before session bootstrap completes',
      (tester) async {
    final controller = AuthSessionController();

    await tester.pumpWidget(StoreReadyGate(controller: controller));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
