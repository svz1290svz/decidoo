import assert from 'node:assert/strict';
import test from 'node:test';
import { decideV7 } from './decision-engine-v7.js';
import type { DecisionCandidateV6 } from './decision-engine-v6.js';

const candidates: DecisionCandidateV6[] = [
  { score: 4.2, reasons: [], meal: { id: '1', name: 'Soup', cuisine: 'Turkish', mealType: 'Dinner', tags: ['soup', 'warm'] }, restaurant: { id: 'r1', name: 'A' } },
  { score: 4.1, reasons: [], meal: { id: '2', name: 'Salad', cuisine: 'Mediterranean', mealType: 'Dinner', tags: ['fresh', 'salad'] }, restaurant: { id: 'r2', name: 'B' } },
];

test('decideV7 combines weather, local time and behavior-history signals', () => {
  const result = decideV7(candidates, {
    weather: { condition: 'Rain', temperatureC: 9 },
    weatherSource: 'open-meteo',
    timeContextResolved: true,
    personalized: true,
  });
  assert.equal(result.primary?.meal.id, '1');
  assert.deepEqual(result.signals, ['AUTOMATIC_WEATHER', 'LOCAL_TIME', 'PERSONALIZATION']);
  assert.ok(result.confidence > 0.75 && result.confidence <= 0.98);
});

test('decideV7 does not claim unavailable context signals', () => {
  const result = decideV7(candidates, {
    weatherSource: null,
    timeContextResolved: true,
    personalized: false,
  });
  assert.deepEqual(result.signals, ['LOCAL_TIME']);
});

test('decideV7 safely handles no matching candidates', () => {
  const result = decideV7([], {
    weatherSource: 'open-meteo',
    timeContextResolved: true,
    personalized: true,
  });
  assert.equal(result.primary, null);
  assert.equal(result.confidence, 0);
  assert.deepEqual(result.signals, []);
});
