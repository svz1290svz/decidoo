import assert from 'node:assert/strict';
import test from 'node:test';
import { decideV6, weatherScoreV6, type DecisionCandidateV6 } from './decision-engine-v6.js';

test('weatherScoreV6 boosts comfort food in cold or wet weather', () => {
  const result = weatherScoreV6(['ramen', 'warm'], {
    condition: 'Rain',
    temperatureC: 9,
    precipitationProbability: 0.8,
  });
  assert.equal(result.score, 0.35);
  assert.deepEqual(result.reasons, ['WEATHER_COMFORT_FIT']);
});

test('weatherScoreV6 boosts fresh food in hot weather', () => {
  const result = weatherScoreV6(['fresh', 'salad'], {
    condition: 'Sunny',
    temperatureC: 31,
  });
  assert.equal(result.score, 0.28);
  assert.deepEqual(result.reasons, ['WEATHER_FRESH_FIT']);
});

test('decideV6 selects one primary decision and at most two alternatives', () => {
  const candidates: DecisionCandidateV6[] = [
    { score: 4.4, reasons: [], meal: { id: '1', name: 'Burger', cuisine: 'American', mealType: 'Dinner', tags: ['burger'] }, restaurant: { id: 'r1', name: 'A' } },
    { score: 4.2, reasons: [], meal: { id: '2', name: 'Ramen', cuisine: 'Japanese', mealType: 'Dinner', tags: ['ramen', 'warm'] }, restaurant: { id: 'r2', name: 'B' } },
    { score: 4.0, reasons: [], meal: { id: '3', name: 'Soup', cuisine: 'Turkish', mealType: 'Dinner', tags: ['soup'] }, restaurant: { id: 'r3', name: 'C' } },
    { score: 3.9, reasons: [], meal: { id: '4', name: 'Pasta', cuisine: 'Italian', mealType: 'Dinner', tags: ['pasta'] }, restaurant: { id: 'r4', name: 'D' } },
  ];

  const result = decideV6(candidates, { condition: 'Rain', temperatureC: 8 });
  assert.equal(result.primary?.meal.id, '2');
  assert.equal(result.alternatives.length, 2);
  assert.ok(result.confidence >= 0.55 && result.confidence <= 0.98);
  assert.ok(result.primary?.reasons.includes('WEATHER_COMFORT_FIT'));
});

test('decideV6 handles an empty candidate list', () => {
  const result = decideV6([], { condition: 'Clear', temperatureC: 22 });
  assert.equal(result.primary, null);
  assert.deepEqual(result.alternatives, []);
  assert.equal(result.confidence, 0);
});
