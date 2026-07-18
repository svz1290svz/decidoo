import 'package:decidoo/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Decidoo opens and exposes revenue navigation', (tester) async {
    await tester.pumpWidget(const DecidooApp());
    await tester.pumpAndSettle();

    expect(find.text('decidoo'), findsOneWidget);
    expect(find.byIcon(Icons.payments_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.payments_outlined));
    await tester.pumpAndSettle();

    expect(find.textContaining('Revenue'), findsWidgets);
  });
}
