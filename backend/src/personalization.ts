import type { Meal, UserPreference } from '@prisma/client';

export type PersonalizationProfile = {
  preferredCuisines: Set<string>;
  preferredMealTypes: Set<string>;
  dislikedIngredients: Set<string>;
  learnedCuisines: Map<string, number>;
  learnedMealTypes: Map<string, number>;
  learnedTags: Map<string, number>;
  dislikedCuisines: Map<string, number>;
  dislikedMealTypes: Map<string, number>;
  dislikedTags: Map<string, number>;
};

export type PreferenceSignal = {
  meal: Pick<Meal, 'cuisine' | 'mealType' | 'tags'> | null;
};

const normalize = (value: string | null | undefined): string =>
  value?.trim().toLocaleLowerCase('en-US') ?? '';

const accumulate = (
  target: Map<string, number>,
  key: string,
  weight: number,
): void => {
  if (!key) return;
  target.set(key, (target.get(key) ?? 0) + weight);
};

export const buildPersonalizationProfile = (
  preference: UserPreference | null,
  positiveSignals: PreferenceSignal[],
  negativeSignals: PreferenceSignal[] = [],
): PersonalizationProfile => {
  const profile: PersonalizationProfile = {
    preferredCuisines: new Set((preference?.favoriteCuisines ?? []).map(normalize)),
    preferredMealTypes: new Set((preference?.preferredMealTypes ?? []).map(normalize)),
    dislikedIngredients: new Set((preference?.dislikedIngredients ?? []).map(normalize)),
    learnedCuisines: new Map(),
    learnedMealTypes: new Map(),
    learnedTags: new Map(),
    dislikedCuisines: new Map(),
    dislikedMealTypes: new Map(),
    dislikedTags: new Map(),
  };

  positiveSignals.forEach((signal, index) => {
    const weight = Math.max(0.2, 1 - index / 125);
    accumulate(profile.learnedCuisines, normalize(signal.meal?.cuisine), weight);
    accumulate(profile.learnedMealTypes, normalize(signal.meal?.mealType), weight);
    signal.meal?.tags.forEach((tag) => accumulate(profile.learnedTags, normalize(tag), weight * 0.5));
  });

  negativeSignals.forEach((signal, index) => {
    const weight = Math.max(0.15, 0.9 - index / 140);
    accumulate(profile.dislikedCuisines, normalize(signal.meal?.cuisine), weight);
    accumulate(profile.dislikedMealTypes, normalize(signal.meal?.mealType), weight);
    signal.meal?.tags.forEach((tag) => accumulate(profile.dislikedTags, normalize(tag), weight * 0.45));
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

  const negativeCuisine = Math.min((profile.dislikedCuisines.get(cuisine) ?? 0) * 0.12, 0.9);
  const negativeMealType = Math.min((profile.dislikedMealTypes.get(mealType) ?? 0) * 0.08, 0.55);
  const negativeTags = Math.min(
    meal.tags.reduce((total, tag) => total + (profile.dislikedTags.get(normalize(tag)) ?? 0), 0) * 0.04,
    0.6,
  );

  const explicit = explicitCuisine + explicitMealType;
  const learned = learnedCuisine + learnedMealType + learnedTags;
  const negative = negativeCuisine + negativeMealType + negativeTags;
  return {
    score: explicit + learned - negative,
    excluded: false,
    reasons: [
      explicit > 0 ? 'PREFERENCE_MATCH' : null,
      learned > 0.2 ? 'BASED_ON_YOUR_ACTIVITY' : null,
      negative > 0.15 ? 'NEGATIVE_HISTORY_PENALTY' : null,
    ].filter((value): value is string => Boolean(value)),
  };
};
