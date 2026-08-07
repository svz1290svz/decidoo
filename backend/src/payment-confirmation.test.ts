import assert from 'node:assert/strict';
import test from 'node:test';
import {
  campaignStatusForConfirmation,
  secureSecretMatches,
  subscriptionStatusForConfirmation,
} from './payment-confirmation.js';

test('payment confirmation secret uses exact constant-time compatible matching', () => {
  const secret = '12345678901234567890123456789012';
  assert.equal(secureSecretMatches(secret, secret), true);
  assert.equal(secureSecretMatches(`${secret}x`, secret), false);
  assert.equal(secureSecretMatches(undefined, secret), false);
});

test('campaign payment states activate or cancel only campaigns', () => {
  assert.equal(campaignStatusForConfirmation('CAMPAIGN_PAID'), 'ACTIVE');
  assert.equal(campaignStatusForConfirmation('CAMPAIGN_REFUNDED'), 'CANCELLED');
  assert.equal(campaignStatusForConfirmation('SUBSCRIPTION_ACTIVE'), null);
});

test('subscription payment states map independently from campaigns', () => {
  assert.equal(subscriptionStatusForConfirmation('SUBSCRIPTION_ACTIVE'), 'ACTIVE');
  assert.equal(subscriptionStatusForConfirmation('SUBSCRIPTION_PAST_DUE'), 'PAST_DUE');
  assert.equal(subscriptionStatusForConfirmation('SUBSCRIPTION_CANCELLED'), 'CANCELLED');
  assert.equal(subscriptionStatusForConfirmation('CAMPAIGN_PAID'), null);
});
