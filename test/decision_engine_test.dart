import 'dart:math';

import 'package:decidoo/src/data/food_catalog.dart';
import 'package:decidoo/src/domain/food.dart';
import 'package:decidoo/src/services/decision_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DecisionEngine', () {
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
      expect(result.confidence, isA<double>());
      expect(result.confidence, inInclusiveRange(.55, .98));
      expect(result.reasons, isNotEmpty);
    });

    test('never returns an excluded tag', () {
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

    test('fails safely when restrictions exclude the full catalog', () {
      final engine = DecisionEngine(random: Random(1));

      expect(
        () => engine.decide(
          foodCatalog,
          const DecisionRequest(
            goal: FoodGoal.surpriseMe,
            priceLevel: PriceLevel.standard,
            mealMoment: MealMoment.lunch,
            excludedTags: {'fish', 'chicken', 'beef', 'vegetarian', 'vegan'},
          ),
        ),
        throwsStateError,
      );
    });

    test('rejects an empty catalog', () {
      final engine = DecisionEngine(random: Random(1));

      expect(
        () => engine.decide(
          const [],
          const DecisionRequest(
            goal: FoodGoal.surpriseMe,
            priceLevel: PriceLevel.standard,
            mealMoment: MealMoment.lunch,
          ),
        ),
        throwsStateError,
      );
    });
  });
}
