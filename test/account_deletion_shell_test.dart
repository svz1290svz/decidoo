import 'package:decidoo/src/auth/auth_session_controller.dart';
import 'package:decidoo/src/privacy/account_deletion_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('account deletion shell is safe at the app root', (tester) async {
    await tester.pumpWidget(
      AccountDeletionShell(
        controller: AuthSessionController(),
        child: const MaterialApp(home: Scaffold(body: Text('Decidoo'))),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.privacy_tip_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.privacy_tip_outlined));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Delete my account'), findsOneWidget);
    expect(find.text('PERMANENTLY DELETE ACCOUNT'), findsOneWidget);
  });
}
