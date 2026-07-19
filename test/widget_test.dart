import 'package:decidoo/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('premium Decidoo shell opens and exposes core navigation', (tester) async {
    await tester.pumpWidget(const DecidooApp());
    await tester.pumpAndSettle();

    expect(find.text('AI DECISION ENGINE'), findsOneWidget);
    expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
  });

  testWidgets('decision flow renders an animated recommendation', (tester) async {
    await tester.pumpWidget(const DecidooApp());
    await tester.pumpAndSettle();

    final decisionList = find.byType(ListView).first;
    await tester.drag(decisionList, const Offset(0, -560));
    await tester.pumpAndSettle();

    final decideButton = find.byKey(const Key('decide-button'));
    expect(decideButton, findsOneWidget);
    await tester.tap(decideButton);
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsWidgets);
  });

  testWidgets('revenue hub remains reachable', (tester) async {
    await tester.pumpWidget(const DecidooApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.payments_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Revenue Hub'), findsOneWidget);
    expect(find.text('Decidoo Premium'), findsWidgets);
  });
}
