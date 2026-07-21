import assert from 'node:assert/strict';
import test from 'node:test';
import {
  hashPassword,
  hashToken,
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyPassword,
  verifyRefreshToken,
} from './auth.js';

test('password hashes verify only the original password', async () => {
  const hash = await hashPassword('A-strong-password-123');
  assert.equal(await verifyPassword('A-strong-password-123', hash), true);
  assert.equal(await verifyPassword('wrong-password', hash), false);
  assert.notEqual(hash, 'A-strong-password-123');
});

test('access tokens preserve user and role claims', () => {
  const token = signAccessToken('user-123', 'ADMIN');
  const claims = verifyAccessToken(token);
  assert.equal(claims.sub, 'user-123');
  assert.equal(claims.role, 'ADMIN');
  assert.equal(claims.type, 'access');
});

test('refresh tokens are distinct and verifiable', () => {
  const first = signRefreshToken('user-123');
  const second = signRefreshToken('user-123');
  assert.notEqual(first, second);
  assert.equal(verifyRefreshToken(first).sub, 'user-123');
  assert.equal(verifyRefreshToken(first).type, 'refresh');
});

test('token hashing is deterministic without exposing raw token', () => {
  const raw = 'refresh-token-value';
  const first = hashToken(raw);
  const second = hashToken(raw);
  assert.equal(first, second);
  assert.notEqual(first, raw);
  assert.equal(first.length, 64);
});

test('access token cannot be accepted as refresh token', () => {
  const token = signAccessToken('user-123', 'USER');
  assert.throws(() => verifyRefreshToken(token));
});
