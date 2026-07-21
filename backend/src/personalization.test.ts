import assert from 'node:assert/strict';
import test from 'node:test';
import {
  buildPersonalizationProfile,
  personalizationScore,
} from './personalization.js';

const preference = {
  id: 'pref-1',
  userId: 'user-1',
  minBudget: null,
  maxBudget: null,
  maxDistanceKm: null,
  vegetarian: false,
  vegan: false,
  halalOnly: false,
  glutenFree: false,
  lactoseFree: false,
  dislikedIngredients: ['mushroom'],
  favoriteCuisines: ['Turkish'],
  preferredMealTypes: ['Dinner'],
  createdAt: new Date(),
  updatedAt: new Date(),
};

test('explicit and learned preferences increase score', () => {
  const profile = buildPersonalizationProfile(preference, [
    {
      meal: {
        cuisine: 'Turkish',
        mealType: 'Dinner',
        tags: ['grill'],
      },
    },
  ]);

  const result = personalizationScore(
    {
      cuisine: 'Turkish',
      mealType: 'Dinner',
      tags: ['grill'],
      ingredients: ['beef', 'pepper'],
    },
    profile,
  );

  assert.equal(result.excluded, false);
  assert.ok(result.score > 1);
  assert.ok(result.reasons.includes('PREFERENCE_MATCH'));
  assert.ok(result.reasons.includes('BASED_ON_YOUR_ACTIVITY'));
});

test('disliked ingredient excludes a meal', () => {
  const profile = buildPersonalizationProfile(preference, []);
  const result = personalizationScore(
    {
      cuisine: 'Turkish',
      mealType: 'Dinner',
      tags: [],
      ingredients: ['Mushroom'],
    },
    profile,
  );

  assert.equal(result.excluded, true);
  assert.equal(result.score, 0);
});
