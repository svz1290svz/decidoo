import 'package:decidoo/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpAtSize(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: const DecidooApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone layout has no initial overflow', (tester) async {
    await pumpAtSize(tester, const Size(360, 800));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('decide-button')), findsOneWidget);
  });

  testWidgets('tablet layout remains usable', (tester) async {
    await pumpAtSize(tester, const Size(1024, 1366));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
  });

  testWidgets('large accessibility text does not crash navigation', (tester) async {
    await pumpAtSize(
      tester,
      const Size(430, 932),
      textScale: 1.6,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary action exposes a semantic button', (tester) async {
    await pumpAtSize(tester, const Size(430, 932));
    final semantics = tester.getSemantics(find.byKey(const Key('decide-button')));
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
    expect(semantics.label, isNotEmpty);
  });
}
