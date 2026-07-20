import { createHash, randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';
import jwt, { type JwtPayload } from 'jsonwebtoken';
import { env } from './config.js';

export type AccessClaims = JwtPayload & {
  sub: string;
  role: string;
  type: 'access';
};

export type RefreshClaims = JwtPayload & {
  sub: string;
  jti: string;
  type: 'refresh';
};

export const hashPassword = (password: string): Promise<string> => bcrypt.hash(password, 12);
export const verifyPassword = (password: string, hash: string): Promise<boolean> => bcrypt.compare(password, hash);
export const hashToken = (token: string): string => createHash('sha256').update(token).digest('hex');

export const signAccessToken = (userId: string, role: string): string =>
  jwt.sign({ role, type: 'access' }, env.JWT_ACCESS_SECRET, {
    subject: userId,
    expiresIn: env.ACCESS_TOKEN_TTL_MINUTES * 60,
  });

export const signRefreshToken = (userId: string): string =>
  jwt.sign({ type: 'refresh' }, env.JWT_REFRESH_SECRET, {
    subject: userId,
    jwtid: randomUUID(),
    expiresIn: env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60,
  });

export const verifyAccessToken = (token: string): AccessClaims => {
  const claims = jwt.verify(token, env.JWT_ACCESS_SECRET);
  if (typeof claims === 'string' || claims.type !== 'access' || !claims.sub || !claims.role) {
    throw new Error('Invalid access token');
  }
  return claims as AccessClaims;
};

export const verifyRefreshToken = (token: string): RefreshClaims => {
  const claims = jwt.verify(token, env.JWT_REFRESH_SECRET);
  if (typeof claims === 'string' || claims.type !== 'refresh' || !claims.sub || !claims.jti) {
    throw new Error('Invalid refresh token');
  }
  return claims as RefreshClaims;
};

export const refreshExpiry = (): Date => {
  const expiresAt = new Date();
  expiresAt.setUTCDate(expiresAt.getUTCDate() + env.REFRESH_TOKEN_TTL_DAYS);
  return expiresAt;
};
