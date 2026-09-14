import 'package:decidoo/src/services/app_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V7 decision response becomes primary plus alternatives', () {
    final results = parseDecisionResults({
      'decision': {'score': 5.2, 'meal': {'id': 'primary'}},
      'alternatives': [
        {'score': 4.9, 'meal': {'id': 'alternative'}},
      ],
    });

    expect(results, hasLength(2));
    expect((results.first['meal'] as Map)['id'], 'primary');
    expect((results.last['meal'] as Map)['id'], 'alternative');
  });

  test('V7 no-match response becomes an empty list', () {
    expect(
      parseDecisionResults({'decision': null, 'alternatives': const []}),
      isEmpty,
    );
  });
}
