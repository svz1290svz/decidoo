import assert from 'node:assert/strict';
import test from 'node:test';
import { distanceKm } from './recommendation-routes.js';

test('distance is zero for identical coordinates', () => {
  assert.equal(distanceKm(39.7767, 30.5206, 39.7767, 30.5206), 0);
});

test('distance calculation is symmetric', () => {
  const first = distanceKm(39.7767, 30.5206, 41.0082, 28.9784);
  const second = distanceKm(41.0082, 28.9784, 39.7767, 30.5206);
  assert.ok(Math.abs(first - second) < 0.000001);
});

test('Eskişehir to Istanbul is within a realistic range', () => {
  const result = distanceKm(39.7767, 30.5206, 41.0082, 28.9784);
  assert.ok(result > 180);
  assert.ok(result < 220);
});
