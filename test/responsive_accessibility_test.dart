import 'dart:ui';

import 'package:decidoo/src/auth/auth_session_controller.dart';
import 'package:decidoo/src/management_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpManagementAtSize(
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
      child: ManagementApp(
        controller: AuthSessionController(),
        isAdmin: true,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('phone management layout renders without overflow', (tester) async {
    await pumpManagementAtSize(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.text('Decidoo Admin'), findsOneWidget);
  });

  testWidgets('tablet management layout remains usable', (tester) async {
    await pumpManagementAtSize(tester, const Size(1024, 1366));
    expect(tester.takeException(), isNull);
    expect(find.text('Operasyon özeti'), findsOneWidget);
  });

  testWidgets('large accessibility text keeps core controls visible', (tester) async {
    await pumpManagementAtSize(
      tester,
      const Size(430, 932),
      textScale: 1.6,
    );
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Çıkış yap'), findsOneWidget);
  });

  testWidgets('logout control exposes semantic tap action', (tester) async {
    await pumpManagementAtSize(tester, const Size(430, 932));
    final semantics = tester
        .getSemantics(find.byTooltip('Çıkış yap'))
        .getSemanticsData();
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
    expect(semantics.label, isNotEmpty);
  });
}
