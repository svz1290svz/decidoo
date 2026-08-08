import assert from 'node:assert/strict';
import test from 'node:test';
import { ZodError } from 'zod';
import { parseEnv } from './config.js';

const base = {
  DATABASE_URL: 'postgresql://user:pass@localhost:5432/decidoo',
  JWT_ACCESS_SECRET: 'access-secret-12345678901234567890',
  JWT_REFRESH_SECRET: 'refresh-secret-123456789012345678',
};

test('production rejects startup without payment and push secrets', () => {
  assert.throws(
    () => parseEnv({ ...base, NODE_ENV: 'production' }),
    (error: unknown) => {
      assert.ok(error instanceof ZodError);
      const paths = error.issues.map((issue) => issue.path.join('.'));
      assert.ok(paths.includes('PUSH_TOKEN_ENCRYPTION_KEY'));
      assert.ok(paths.includes('PAYMENT_CONFIRMATION_SECRET'));
      return true;
    },
  );
});

test('production accepts complete monetization security configuration', () => {
  const parsed = parseEnv({
    ...base,
    NODE_ENV: 'production',
    PUSH_TOKEN_ENCRYPTION_KEY: 'a'.repeat(64),
    PAYMENT_CONFIRMATION_SECRET: 'payment-secret-12345678901234567890',
  });
  assert.equal(parsed.NODE_ENV, 'production');
  assert.equal(parsed.PAYMENT_CONFIRMATION_SECRET?.length, 35);
});

test('development can run without external payment integration', () => {
  const parsed = parseEnv({ ...base, NODE_ENV: 'development' });
  assert.equal(parsed.NODE_ENV, 'development');
  assert.equal(parsed.PAYMENT_CONFIRMATION_SECRET, undefined);
});
