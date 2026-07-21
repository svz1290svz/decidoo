import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { verifyAccessToken } from './auth.js';
import { prisma } from './db.js';

const preferenceSchema = z.object({
  minBudget: z.coerce.number().nonnegative().max(100000).nullable().optional(),
  maxBudget: z.coerce.number().positive().max(100000).nullable().optional(),
  maxDistanceKm: z.coerce.number().positive().max(200).nullable().optional(),
  vegetarian: z.boolean().optional(),
  vegan: z.boolean().optional(),
  halalOnly: z.boolean().optional(),
  glutenFree: z.boolean().optional(),
  lactoseFree: z.boolean().optional(),
  dislikedIngredients: z.array(z.string().trim().min(1).max(80)).max(100).optional(),
  favoriteCuisines: z.array(z.string().trim().min(1).max(80)).max(50).optional(),
  preferredMealTypes: z.array(z.string().trim().min(1).max(80)).max(50).optional(),
}).refine(
  (value) => value.minBudget == null || value.maxBudget == null || value.minBudget <= value.maxBudget,
  { message: 'minBudget cannot exceed maxBudget' },
);

const userIdFromRequest = (request: FastifyRequest): string => {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) throw new Error('UNAUTHORIZED');
  return verifyAccessToken(header.slice(7).trim()).sub;
};

const serializePreference = (preference: {
  minBudget: unknown;
  maxBudget: unknown;
  maxDistanceKm: unknown;
  [key: string]: unknown;
} | null) => preference ? {
  ...preference,
  minBudget: preference.minBudget == null ? null : Number(preference.minBudget),
  maxBudget: preference.maxBudget == null ? null : Number(preference.maxBudget),
  maxDistanceKm: preference.maxDistanceKm == null ? null : Number(preference.maxDistanceKm),
} : null;

export const registerEngagementRoutes = async (app: FastifyInstance): Promise<void> => {
  app.get('/v1/me/preferences', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const preference = await prisma.userPreference.findUnique({ where: { userId } });
      return { preference: serializePreference(preference) };
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.put('/v1/me/preferences', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const parsed = preferenceSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
      }
      const preference = await prisma.userPreference.upsert({
        where: { userId },
        create: { userId, ...parsed.data },
        update: parsed.data,
      });
      await prisma.user.update({ where: { id: userId }, data: { onboardingDone: true } });
      return { preference: serializePreference(preference) };
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.get('/v1/me/recent-searches', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const sessions = await prisma.recommendationSession.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 30,
        select: {
          id: true,
          budget: true,
          maxDistanceKm: true,
          latitude: true,
          longitude: true,
          requestContext: true,
          createdAt: true,
        },
      });
      return {
        searches: sessions.map((session) => ({
          ...session,
          budget: session.budget == null ? null : Number(session.budget),
          maxDistanceKm: session.maxDistanceKm == null ? null : Number(session.maxDistanceKm),
          latitude: session.latitude == null ? null : Number(session.latitude),
          longitude: session.longitude == null ? null : Number(session.longitude),
        })),
      };
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.delete('/v1/me/recent-searches', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      await prisma.recommendationSession.deleteMany({ where: { userId } });
      return reply.code(204).send();
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.get('/v1/me/personalization-summary', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const [preference, feedback, favorites] = await Promise.all([
        prisma.userPreference.findUnique({ where: { userId } }),
        prisma.recommendationLog.groupBy({
          by: ['action'],
          where: { userId, action: { not: null } },
          _count: { _all: true },
        }),
        prisma.favorite.count({ where: { userId } }),
      ]);
      return {
        preference: serializePreference(preference),
        feedback: Object.fromEntries(feedback.map((item) => [item.action ?? 'UNKNOWN', item._count._all])),
        favorites,
      };
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });
};
