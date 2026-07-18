enum PriceLevel { budget, standard, premium }

enum MealMoment { breakfast, lunch, dinner, lateNight }

enum FoodGoal { surpriseMe, light, filling, healthy, comfort }

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.emoji,
    required this.cuisine,
    required this.description,
    required this.priceLevel,
    required this.mealMoments,
    required this.goals,
    required this.tags,
    required this.estimatedMinutes,
    required this.popularity,
  });

  final String id;
  final String name;
  final String emoji;
  final String cuisine;
  final String description;
  final PriceLevel priceLevel;
  final Set<MealMoment> mealMoments;
  final Set<FoodGoal> goals;
  final Set<String> tags;
  final int estimatedMinutes;
  final double popularity;
}

class DecisionRequest {
  const DecisionRequest({
    required this.goal,
    required this.priceLevel,
    required this.mealMoment,
    this.excludedTags = const {},
    this.previousFoodIds = const {},
  });

  final FoodGoal goal;
  final PriceLevel priceLevel;
  final MealMoment mealMoment;
  final Set<String> excludedTags;
  final Set<String> previousFoodIds;
}

class DecisionResult {
  const DecisionResult({
    required this.food,
    required this.confidence,
    required this.reasons,
  });

  final Food food;
  final double confidence;
  final List<String> reasons;
}
