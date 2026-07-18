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
      final reasons = <String>[];

      if (food.mealMoments.contains(request.mealMoment)) {
        score += 38;
        reasons.add('Strong match for this meal');
      }
      if (food.priceLevel == request.priceLevel) {
        score += 24;
        reasons.add('Fits your budget');
      }
      if (request.goal == FoodGoal.surpriseMe ||
          food.goals.contains(request.goal)) {
        score += 28;
        reasons.add('Matches what you want right now');
      }
      if (!request.previousFoodIds.contains(food.id)) {
        score += 12;
        reasons.add('Adds variety to recent choices');
      } else {
        score -= 18;
      }

      score += _random.nextDouble() * 7;
      return _ScoredFood(food, score, reasons);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final winner = scored.first;
    return DecisionResult(
      food: winner.food,
      confidence: (winner.score / 125).clamp(.55, .98).toDouble(),
      reasons: winner.reasons.take(3).toList(growable: false),
    );
  }
}

class _ScoredFood {
  const _ScoredFood(this.food, this.score, this.reasons);

  final Food food;
  final double score;
  final List<String> reasons;
}
