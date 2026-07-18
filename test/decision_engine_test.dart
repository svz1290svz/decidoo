import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:decidoo/src/data/food_catalog.dart';
import 'package:decidoo/src/domain/food.dart';
import 'package:decidoo/src/services/decision_engine.dart';

void main() {
  test('returns a relevant dinner recommendation', () {
    final engine = DecisionEngine(random: Random(7));
    final result = engine.decide(
      foodCatalog,
      const DecisionRequest(
        goal: FoodGoal.healthy,
        priceLevel: PriceLevel.premium,
        mealMoment: MealMoment.dinner,
      ),
    );

    expect(result.food.mealMoments, contains(MealMoment.dinner));
    expect(result.confidence, inInclusiveRange(.55, .98));
    expect(result.reasons, isNotEmpty);
  });

  test('avoids excluded tags', () {
    final engine = DecisionEngine(random: Random(3));
    final result = engine.decide(
      foodCatalog,
      const DecisionRequest(
        goal: FoodGoal.surpriseMe,
        priceLevel: PriceLevel.standard,
        mealMoment: MealMoment.lunch,
        excludedTags: {'fish'},
      ),
    );

    expect(result.food.tags, isNot(contains('fish')));
  });
}
