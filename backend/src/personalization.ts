import type { Meal, UserPreference } from '@prisma/client';

export type PersonalizationProfile = {
  preferredCuisines: Set<string>;
  preferredMealTypes: Set<string>;
  dislikedIngredients: Set<string>;
  learnedCuisines: Map<string, number>;
  learnedMealTypes: Map<string, number>;
  learnedTags: Map<string, number>;
};

const normalize = (value: string | null | undefined): string =>
  value?.trim().toLocaleLowerCase('en-US') ?? '';

export const buildPersonalizationProfile = (
  preference: UserPreference | null,
  signals: Array<{
    meal: Pick<Meal, 'cuisine' | 'mealType' | 'tags'> | null;
  }>,
): PersonalizationProfile => {
  const profile: PersonalizationProfile = {
    preferredCuisines: new Set((preference?.favoriteCuisines ?? []).map(normalize)),
    preferredMealTypes: new Set((preference?.preferredMealTypes ?? []).map(normalize)),
    dislikedIngredients: new Set((preference?.dislikedIngredients ?? []).map(normalize)),
    learnedCuisines: new Map(),
    learnedMealTypes: new Map(),
    learnedTags: new Map(),
  };

  signals.forEach((signal, index) => {
    const weight = Math.max(0.2, 1 - index / 125);
    const cuisine = normalize(signal.meal?.cuisine);
    const mealType = normalize(signal.meal?.mealType);
    if (cuisine) {
      profile.learnedCuisines.set(cuisine, (profile.learnedCuisines.get(cuisine) ?? 0) + weight);
    }
    if (mealType) {
      profile.learnedMealTypes.set(mealType, (profile.learnedMealTypes.get(mealType) ?? 0) + weight);
    }
    signal.meal?.tags.forEach((tag) => {
      const key = normalize(tag);
      if (key) profile.learnedTags.set(key, (profile.learnedTags.get(key) ?? 0) + weight * 0.5);
    });
  });

  return profile;
};

export const personalizationScore = (
  meal: Pick<Meal, 'cuisine' | 'mealType' | 'tags' | 'ingredients'>,
  profile: PersonalizationProfile,
): { score: number; reasons: string[]; excluded: boolean } => {
  const excluded = meal.ingredients.some((ingredient) =>
    profile.dislikedIngredients.has(normalize(ingredient)),
  );
  if (excluded) return { score: 0, reasons: [], excluded: true };

  const cuisine = normalize(meal.cuisine);
  const mealType = normalize(meal.mealType);
  const explicitCuisine = profile.preferredCuisines.has(cuisine) ? 0.7 : 0;
  const explicitMealType = profile.preferredMealTypes.has(mealType) ? 0.45 : 0;
  const learnedCuisine = Math.min((profile.learnedCuisines.get(cuisine) ?? 0) * 0.08, 0.8);
  const learnedMealType = Math.min((profile.learnedMealTypes.get(mealType) ?? 0) * 0.05, 0.45);
  const learnedTags = Math.min(
    meal.tags.reduce((total, tag) => total + (profile.learnedTags.get(normalize(tag)) ?? 0), 0) * 0.025,
    0.4,
  );

  const explicit = explicitCuisine + explicitMealType;
  const learned = learnedCuisine + learnedMealType + learnedTags;
  return {
    score: explicit + learned,
    excluded: false,
    reasons: [
      explicit > 0 ? 'PREFERENCE_MATCH' : null,
      learned > 0.2 ? 'BASED_ON_YOUR_ACTIVITY' : null,
    ].filter((value): value is string => Boolean(value)),
  };
};
