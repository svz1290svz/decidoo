import 'package:decidoo/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Decidoo launches and shows the brand', (tester) async {
    await tester.pumpWidget(const DecidooApp());
    await tester.pumpAndSettle();

    expect(find.text('decidoo'), findsOneWidget);
  });
}
