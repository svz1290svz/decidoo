import 'dart:math';

import '../domain/food.dart';

class DecisionEngine {
  DecisionEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  DecisionResult decide(List<Food> catalog, DecisionRequest request) {
    if (catalog.isEmpty) {
      throw StateError('Food catalog cannot be empty.');
    }

    final candidates = catalog
        .where((food) => !food.tags.any(request.excludedTags.contains))
        .toList(growable: false);

    if (candidates.isEmpty) {
      throw StateError('No food matches the active dietary restrictions.');
    }

    final scored = candidates.map((food) {
      var score = food.popularity * 20;
      final reasonKeys = <String>[];

      if (food.mealMoments.contains(request.mealMoment)) {
        score += 38;
        reasonKeys.add('reasonMeal');
      }
      if (food.priceLevel == request.priceLevel) {
        score += 24;
        reasonKeys.add('reasonBudget');
      }
      if (request.goal == FoodGoal.surpriseMe ||
          food.goals.contains(request.goal)) {
        score += 28;
        reasonKeys.add('reasonGoal');
      }
      if (!request.previousFoodIds.contains(food.id)) {
        score += 12;
        reasonKeys.add('reasonDifferent');
      } else {
        score -= 18;
      }

      score += _random.nextDouble() * 7;
      return _ScoredFood(food, score, reasonKeys);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final winner = scored.first;
    return DecisionResult(
      food: winner.food,
      confidence: (winner.score / 125).clamp(.55, .98).toDouble(),
      reasons: winner.reasonKeys.take(3).toList(growable: false),
    );
  }
}

class _ScoredFood {
  const _ScoredFood(this.food, this.score, this.reasonKeys);

  final Food food;
  final double score;
  final List<String> reasonKeys;
}
