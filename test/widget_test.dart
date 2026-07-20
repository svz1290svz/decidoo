import 'package:decidoo/src/complete_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> enterApp(WidgetTester tester) async {
  await tester.pumpWidget(const CompleteDecidooApp());
  await tester.pumpAndSettle();
  for (var i = 0; i < 3; i++) {
    await tester.tap(find.text(i == 2 ? 'GET STARTED' : 'CONTINUE'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Continue as guest'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onboarding transitions into login', (tester) async {
    await tester.pumpWidget(const CompleteDecidooApp());
    await tester.pumpAndSettle();
    expect(find.text('Stop overthinking.'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Made for you.'), findsOneWidget);
  });

  testWidgets('main app exposes five complete destinations', (tester) async {
    await enterApp(tester);
    expect(find.text('Decide'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('decision flow creates a recommendation', (tester) async {
    await enterApp(tester);
    final button = find.byKey(const Key('complete-decide-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('personal match'), findsOneWidget);
  });

  testWidgets('profile contains settings and premium entry', (tester) async {
    await enterApp(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock Decidoo Premium'), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Privacy & data'), findsOneWidget);
  });
}
