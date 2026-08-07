import assert from 'node:assert/strict';
import test from 'node:test';
import { canBillAction, minorUnits, normalizeCountry, normalizeCurrency, sponsoredDisclosure } from './monetization-domain.js';

test('only high-intent restaurant actions are billable', () => {
  assert.equal(canBillAction('RESTAURANT_OPENED'), true);
  assert.equal(canBillAction('NAVIGATION_STARTED'), true);
  assert.equal(canBillAction('ORDER_CLICKED'), true);
  assert.equal(canBillAction('VIEWED'), false);
  assert.equal(canBillAction('LIKED'), false);
});

test('currency minor units support zero-decimal markets', () => {
  assert.equal(minorUnits(12.34, 'USD'), 1234n);
  assert.equal(minorUnits(1200, 'JPY'), 1200n);
});

test('country currency and sponsor labels are normalized', () => {
  assert.equal(normalizeCountry(' tr '), 'TR');
  assert.equal(normalizeCurrency(' eur '), 'EUR');
  assert.equal(sponsoredDisclosure('tr'), 'Sponsorlu');
  assert.equal(sponsoredDisclosure('ar'), 'إعلان ممول');
});
