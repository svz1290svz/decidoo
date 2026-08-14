import assert from 'node:assert/strict';
import test from 'node:test';
import { confidenceV5, contextScoreV5, diversifyV5, freshnessScoreV5, isOpenAt } from './decision-engine-v5.js';

test('operating hours support normal and overnight windows', () => {
  const monday = new Date('2026-08-10T18:00:00Z');
  assert.equal(isOpenAt([{ dayOfWeek: 1, opensAt: '09:00', closesAt: '23:00', isClosed: false }], monday, 'UTC'), true);
  const tuesdayEarly = new Date('2026-08-11T01:00:00Z');
  assert.equal(isOpenAt([{ dayOfWeek: 1, opensAt: '18:00', closesAt: '02:00', isClosed: false }], tuesdayEarly, 'UTC'), true);
});

test('hunger and mood produce contextual score', () => {
  const result = contextScoreV5({ mealType: 'Dinner', tags: ['hearty', 'comfort'], calories: 800, preparationMin: 15, updatedAt: new Date() }, { mealType: 'Dinner', hungerLevel: 5, mood: 'stressed' });
  assert.ok(result.score >= 0.9);
  assert.ok(result.reasons.includes('HUNGER_FIT'));
  assert.ok(result.reasons.includes('MOOD_FIT'));
});

test('fresh menus outrank stale menus', () => {
  const now = new Date('2026-08-14T12:00:00Z');
  assert.ok(freshnessScoreV5(new Date('2026-08-12T12:00:00Z'), now).score > freshnessScoreV5(new Date('2025-12-01T12:00:00Z'), now).score);
  assert.equal(freshnessScoreV5(new Date('2025-12-01T12:00:00Z'), now).stale, true);
});

test('diversity prevents a restaurant from dominating shortlist', () => {
  const ranked = [
    { restaurant: { id: 'r1' }, meal: { cuisine: 'Turkish' }, score: 10 },
    { restaurant: { id: 'r1' }, meal: { cuisine: 'Turkish' }, score: 9.9 },
    { restaurant: { id: 'r1' }, meal: { cuisine: 'Turkish' }, score: 9.8 },
    { restaurant: { id: 'r2' }, meal: { cuisine: 'Italian' }, score: 9.5 },
    { restaurant: { id: 'r3' }, meal: { cuisine: 'Japanese' }, score: 9.4 },
  ];
  const result = diversifyV5(ranked, 4);
  assert.equal(result.filter((item) => item.restaurant.id === 'r1').length, 2);
  assert.ok(result.some((item) => item.restaurant.id === 'r2'));
});

test('confidence reacts to ranking separation', () => {
  assert.ok(confidenceV5([5, 2]) > confidenceV5([5, 4.9]));
});
