import { randomBytes } from 'node:crypto';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import {
  hashPassword,
  hashToken,
  refreshExpiry,
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyPassword,
  verifyRefreshToken,
} from './auth.js';
import { env } from './config.js';
import { prisma } from './db.js';

const registerSchema = z.object({
  email: z.string().email().transform((value) => value.trim().toLowerCase()),
  password: z.string().min(10).max(128),
  displayName: z.string().trim().min(2).max(80).optional(),
  preferredLanguage: z.enum(['tr', 'en']).default('tr'),
});

const loginSchema = z.object({
  email: z.string().email().transform((value) => value.trim().toLowerCase()),
  password: z.string().min(1).max(128),
});

const refreshSchema = z.object({ refreshToken: z.string().min(1) });
const passwordResetRequestSchema = z.object({
  email: z.string().email().transform((value) => value.trim().toLowerCase()),
});
const passwordResetConfirmSchema = z.object({
  token: z.string().min(32).max(256),
  newPassword: z.string().min(10).max(128),
});

const RESET_TOKEN_PREFIX = 'password-reset:';
const RESET_TOKEN_TTL_MINUTES = 30;

const publicUser = (user: {
  id: string;
  email: string | null;
  displayName: string | null;
  role: string;
  preferredLanguage: string;
  onboardingDone: boolean;
}) => ({
  id: user.id,
  email: user.email,
  displayName: user.displayName,
  role: user.role,
  preferredLanguage: user.preferredLanguage,
  onboardingDone: user.onboardingDone,
});

const issueSession = async (userId: string, role: string) => {
  const accessToken = signAccessToken(userId, role);
  const refreshToken = signRefreshToken(userId);
  await prisma.refreshToken.create({
    data: {
      userId,
      tokenHash: hashToken(refreshToken),
      expiresAt: refreshExpiry(),
    },
  });
  return { accessToken, refreshToken };
};

const bearerToken = (request: FastifyRequest): string | null => {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) return null;
  return header.slice(7).trim() || null;
};

const resetTokenHash = (token: string): string => hashToken(`${RESET_TOKEN_PREFIX}${token}`);

const deliverPasswordReset = async (email: string, token: string): Promise<boolean> => {
  const webhookUrl = process.env.PASSWORD_RESET_WEBHOOK_URL;
  if (!webhookUrl) {
    if (env.NODE_ENV !== 'production') {
      console.info(`[decidoo] Password reset token for ${email}: ${token}`);
      return true;
    }
    return false;
  }

  const response = await fetch(webhookUrl, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(process.env.PASSWORD_RESET_WEBHOOK_SECRET
        ? { authorization: `Bearer ${process.env.PASSWORD_RESET_WEBHOOK_SECRET}` }
        : {}),
    },
    body: JSON.stringify({
      event: 'password.reset.requested',
      email,
      token,
      expiresInMinutes: RESET_TOKEN_TTL_MINUTES,
    }),
  });
  return response.ok;
};

export const registerAuthRoutes = async (app: FastifyInstance): Promise<void> => {
  app.post('/v1/auth/register', async (request, reply) => {
    const parsed = registerSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });

    const existing = await prisma.user.findUnique({ where: { email: parsed.data.email } });
    if (existing) return reply.code(409).send({ error: 'EMAIL_ALREADY_REGISTERED' });

    const user = await prisma.user.create({
      data: {
        email: parsed.data.email,
        passwordHash: await hashPassword(parsed.data.password),
        displayName: parsed.data.displayName,
        preferredLanguage: parsed.data.preferredLanguage,
      },
    });

    const tokens = await issueSession(user.id, user.role);
    return reply.code(201).send({ user: publicUser(user), ...tokens });
  });

  app.post('/v1/auth/login', async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT' });

    const user = await prisma.user.findUnique({ where: { email: parsed.data.email } });
    const valid = user?.passwordHash ? await verifyPassword(parsed.data.password, user.passwordHash) : false;
    if (!user || !valid) return reply.code(401).send({ error: 'INVALID_CREDENTIALS' });
    if (user.status !== 'ACTIVE') return reply.code(403).send({ error: 'ACCOUNT_UNAVAILABLE' });

    const tokens = await issueSession(user.id, user.role);
    return { user: publicUser(user), ...tokens };
  });

  app.post('/v1/auth/password-reset/request', async (request, reply) => {
    const parsed = passwordResetRequestSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT' });

    const user = await prisma.user.findUnique({ where: { email: parsed.data.email } });
    if (!user || user.status !== 'ACTIVE') return reply.code(202).send({ accepted: true });

    const token = randomBytes(32).toString('base64url');
    const expiresAt = new Date(Date.now() + RESET_TOKEN_TTL_MINUTES * 60_000);
    await prisma.$transaction([
      prisma.refreshToken.updateMany({
        where: {
          userId: user.id,
          tokenHash: { startsWith: hashToken(RESET_TOKEN_PREFIX).slice(0, 0) },
          revokedAt: null,
        },
        data: { revokedAt: new Date() },
      }),
      prisma.refreshToken.create({
        data: {
          userId: user.id,
          tokenHash: resetTokenHash(token),
          expiresAt,
        },
      }),
    ]);

    const delivered = await deliverPasswordReset(parsed.data.email, token);
    if (!delivered) {
      app.log.error({ email: parsed.data.email }, 'Password reset delivery provider is not configured');
      return reply.code(503).send({ error: 'DELIVERY_UNAVAILABLE' });
    }
    return reply.code(202).send({ accepted: true });
  });

  app.post('/v1/auth/password-reset/confirm', async (request, reply) => {
    const parsed = passwordResetConfirmSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT' });

    const stored = await prisma.refreshToken.findUnique({
      where: { tokenHash: resetTokenHash(parsed.data.token) },
    });
    if (!stored || stored.revokedAt || stored.expiresAt <= new Date()) {
      return reply.code(400).send({ error: 'INVALID_OR_EXPIRED_RESET_TOKEN' });
    }

    await prisma.$transaction([
      prisma.user.update({
        where: { id: stored.userId },
        data: { passwordHash: await hashPassword(parsed.data.newPassword) },
      }),
      prisma.refreshToken.updateMany({
        where: { userId: stored.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);
    return reply.code(204).send();
  });

  app.post('/v1/auth/refresh', async (request, reply) => {
    const parsed = refreshSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT' });

    try {
      const claims = verifyRefreshToken(parsed.data.refreshToken);
      const stored = await prisma.refreshToken.findUnique({ where: { tokenHash: hashToken(parsed.data.refreshToken) } });
      if (!stored || stored.userId !== claims.sub || stored.revokedAt || stored.expiresAt <= new Date()) {
        return reply.code(401).send({ error: 'INVALID_REFRESH_TOKEN' });
      }

      const user = await prisma.user.findUnique({ where: { id: claims.sub } });
      if (!user || user.status !== 'ACTIVE') return reply.code(401).send({ error: 'INVALID_REFRESH_TOKEN' });

      await prisma.refreshToken.update({ where: { id: stored.id }, data: { revokedAt: new Date() } });
      return { user: publicUser(user), ...(await issueSession(user.id, user.role)) };
    } catch {
      return reply.code(401).send({ error: 'INVALID_REFRESH_TOKEN' });
    }
  });

  app.post('/v1/auth/logout', async (request, reply) => {
    const parsed = refreshSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(204).send();
    await prisma.refreshToken.updateMany({
      where: { tokenHash: hashToken(parsed.data.refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return reply.code(204).send();
  });

  app.get('/v1/me', async (request: FastifyRequest, reply: FastifyReply) => {
    const token = bearerToken(request);
    if (!token) return reply.code(401).send({ error: 'AUTH_REQUIRED' });

    try {
      const claims = verifyAccessToken(token);
      const user = await prisma.user.findUnique({ where: { id: claims.sub } });
      if (!user || user.status !== 'ACTIVE') return reply.code(401).send({ error: 'AUTH_REQUIRED' });
      return { user: publicUser(user) };
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });
};
