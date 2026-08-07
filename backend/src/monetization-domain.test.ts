import assert from 'node:assert/strict';
import test from 'node:test';
import {
  canBillAction,
  currencyExponent,
  minorUnits,
  normalizeCountry,
  normalizeCurrency,
  sponsoredDisclosure,
} from './monetization-domain.js';

test('only high-intent restaurant actions are billable', () => {
  assert.equal(canBillAction('RESTAURANT_OPENED'), true);
  assert.equal(canBillAction('NAVIGATION_STARTED'), true);
  assert.equal(canBillAction('ORDER_CLICKED'), true);
  assert.equal(canBillAction('VIEWED'), false);
  assert.equal(canBillAction('LIKED'), false);
});

test('currency minor units support zero two and three decimal markets', () => {
  assert.equal(currencyExponent('JPY'), 0);
  assert.equal(currencyExponent('USD'), 2);
  assert.equal(currencyExponent('KWD'), 3);
  assert.equal(minorUnits(12.34, 'USD'), 1234n);
  assert.equal(minorUnits(1200, 'JPY'), 1200n);
  assert.equal(minorUnits(12.345, 'KWD'), 12345n);
});

test('provider adapters can override currency exponent safely', () => {
  assert.equal(minorUnits(1.2345, 'USD', 4), 12345n);
  assert.throws(() => minorUnits(-1, 'USD'), RangeError);
  assert.throws(() => minorUnits(1, 'USD', 7), RangeError);
});

test('country currency and sponsor labels are normalized', () => {
  assert.equal(normalizeCountry(' tr '), 'TR');
  assert.equal(normalizeCurrency(' eur '), 'EUR');
  assert.equal(sponsoredDisclosure('tr'), 'Sponsorlu');
  assert.equal(sponsoredDisclosure('ar'), 'إعلان ممول');
});
