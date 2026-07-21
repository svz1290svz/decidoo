import { createCipheriv, createHash, randomBytes, randomUUID } from 'node:crypto';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { verifyAccessToken } from './auth.js';
import { env } from './config.js';
import { prisma } from './db.js';

const deviceSchema = z.object({
  token: z.string().trim().min(20).max(4096),
  platform: z.enum(['android', 'ios', 'web']),
  locale: z.string().trim().min(2).max(20).optional(),
  timezone: z.string().trim().min(3).max(80).optional(),
});

const tokenSchema = z.object({ token: z.string().trim().min(20).max(4096) });

const userIdFromRequest = (request: FastifyRequest): string => {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) throw new Error('UNAUTHORIZED');
  return verifyAccessToken(header.slice(7).trim()).sub;
};

const hashToken = (token: string): string => createHash('sha256').update(token).digest('hex');

const encryptToken = (token: string): string => {
  const keyHex = env.PUSH_TOKEN_ENCRYPTION_KEY;
  if (!keyHex) return Buffer.from(token, 'utf8').toString('base64');
  const key = Buffer.from(keyHex, 'hex');
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(token, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [iv, tag, encrypted].map((part) => part.toString('base64url')).join('.');
};

export const registerPushDeviceRoutes = async (app: FastifyInstance): Promise<void> => {
  app.post('/v1/me/push-devices', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const parsed = deviceSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
      }
      const tokenHash = hashToken(parsed.data.token);
      const encryptedToken = encryptToken(parsed.data.token);
      const id = randomUUID();
      await prisma.$executeRaw`
        INSERT INTO "PushDevice" ("id", "userId", "tokenHash", "encryptedToken", "platform", "locale", "timezone", "enabled", "lastSeenAt", "createdAt", "updatedAt")
        VALUES (${id}, ${userId}, ${tokenHash}, ${encryptedToken}, ${parsed.data.platform}, ${parsed.data.locale ?? null}, ${parsed.data.timezone ?? null}, true, NOW(), NOW(), NOW())
        ON CONFLICT ("tokenHash") DO UPDATE SET
          "userId" = EXCLUDED."userId",
          "encryptedToken" = EXCLUDED."encryptedToken",
          "platform" = EXCLUDED."platform",
          "locale" = EXCLUDED."locale",
          "timezone" = EXCLUDED."timezone",
          "enabled" = true,
          "lastSeenAt" = NOW(),
          "updatedAt" = NOW()
      `;
      return reply.code(204).send();
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.delete('/v1/me/push-devices', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const parsed = tokenSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
      }
      const tokenHash = hashToken(parsed.data.token);
      await prisma.$executeRaw`
        UPDATE "PushDevice"
        SET "enabled" = false, "updatedAt" = NOW()
        WHERE "userId" = ${userId} AND "tokenHash" = ${tokenHash}
      `;
      return reply.code(204).send();
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });
};
