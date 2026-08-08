import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const migrationUrl = new URL(
  '../prisma/migrations/20260808030000_campaign_payment_guard/migration.sql',
  import.meta.url,
);

const sql = readFileSync(migrationUrl, 'utf8');

test('prepaid campaign activation requires the exact paid campaign reference', () => {
  assert.match(sql, /NEW\."channel" <> 'PER_ACTION'/);
  assert.match(sql, /p\."status" = 'PAID'/);
  assert.match(sql, /p\."metadata"->>'campaignId' = NEW\."id"/);
  assert.match(sql, /p\."amount" = NEW\."budget"/);
  assert.match(sql, /p\."currency" = NEW\."currency"/);
});

test('guard executes before campaign status becomes active', () => {
  assert.match(sql, /BEFORE UPDATE OF "status"/);
  assert.match(sql, /RAISE EXCEPTION 'PAID_CAMPAIGN_FUNDING_REQUIRED'/);
});
