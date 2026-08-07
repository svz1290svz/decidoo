import assert from 'node:assert/strict';
import test from 'node:test';
import { selectChargeCampaign } from './monetization-billing.js';

const now = new Date('2026-08-08T00:00:00Z');
const campaign = (overrides: Record<string, unknown> = {}) => ({
  id: 'campaign-a',
  channel: 'PER_ACTION' as const,
  status: 'ACTIVE',
  startsAt: new Date('2026-08-01T00:00:00Z'),
  endsAt: new Date('2026-09-01T00:00:00Z'),
  remainingBudget: 100,
  bidPerAction: 2.5,
  currency: 'EUR',
  ...overrides,
});

test('charges only high-intent actions from active funded campaigns', () => {
  assert.deepEqual(selectChargeCampaign([campaign()], 'ORDER_CLICKED', now), {
    campaignId: 'campaign-a',
    amount: 2.5,
    currency: 'EUR',
  });
  assert.equal(selectChargeCampaign([campaign()], 'VIEWED', now), null);
});

test('never selects an expired, paused or underfunded campaign', () => {
  assert.equal(
    selectChargeCampaign([campaign({ status: 'PAUSED' })], 'ORDER_CLICKED', now),
    null,
  );
  assert.equal(
    selectChargeCampaign(
      [campaign({ endsAt: new Date('2026-08-07T23:59:59Z') })],
      'ORDER_CLICKED',
      now,
    ),
    null,
  );
  assert.equal(
    selectChargeCampaign([campaign({ remainingBudget: 1 })], 'ORDER_CLICKED', now),
    null,
  );
});

test('selects the highest eligible bid deterministically', () => {
  const result = selectChargeCampaign(
    [
      campaign({ id: 'low', bidPerAction: 1 }),
      campaign({ id: 'high', bidPerAction: 3 }),
      campaign({ id: 'mid', bidPerAction: 2 }),
    ],
    'NAVIGATION_STARTED',
    now,
  );
  assert.deepEqual(result, {
    campaignId: 'high',
    amount: 3,
    currency: 'EUR',
  });
});

test('boost campaigns are not charged per action', () => {
  assert.equal(
    selectChargeCampaign(
      [campaign({ channel: 'BOOST', bidPerAction: 10 })],
      'ORDER_CLICKED',
      now,
    ),
    null,
  );
});
