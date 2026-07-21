import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { hashPassword, verifyAccessToken, verifyPassword } from './auth.js';
import { prisma } from './db.js';

const profileSchema = z.object({
  displayName: z.string().trim().min(2).max(80).nullable().optional(),
  preferredLanguage: z.enum(['tr', 'en']).optional(),
  currency: z.string().trim().length(3).transform((value) => value.toUpperCase()).optional(),
  timezone: z.string().trim().min(3).max(80).optional(),
});

const passwordSchema = z.object({
  currentPassword: z.string().min(1).max(128),
  newPassword: z.string().min(10).max(128),
});

const favoriteSchema = z.object({
  restaurantId: z.string().cuid().optional(),
  mealId: z.string().cuid().optional(),
}).refine((value) => Boolean(value.restaurantId) !== Boolean(value.mealId), {
  message: 'Exactly one favorite target is required',
});

const userIdFromRequest = (request: FastifyRequest): string => {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) throw new Error('UNAUTHORIZED');
  return verifyAccessToken(header.slice(7).trim()).sub;
};

export const registerAccountRoutes = async (app: FastifyInstance): Promise<void> => {
  app.patch('/v1/me', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const parsed = profileSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });

      const user = await prisma.user.update({
        where: { id: userId },
        data: parsed.data,
        select: {
          id: true,
          email: true,
          displayName: true,
          role: true,
          preferredLanguage: true,
          currency: true,
          timezone: true,
          onboardingDone: true,
        },
      });
      return { user };
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.post('/v1/me/change-password', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const parsed = passwordSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });

      const user = await prisma.user.findUnique({ where: { id: userId } });
      const valid = user?.passwordHash
        ? await verifyPassword(parsed.data.currentPassword, user.passwordHash)
        : false;
      if (!valid) return reply.code(401).send({ error: 'INVALID_CURRENT_PASSWORD' });

      await prisma.$transaction([
        prisma.user.update({
          where: { id: userId },
          data: { passwordHash: await hashPassword(parsed.data.newPassword) },
        }),
        prisma.refreshToken.updateMany({
          where: { userId, revokedAt: null },
          data: { revokedAt: new Date() },
        }),
      ]);
      return reply.code(204).send();
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.get('/v1/favorites', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const favorites = await prisma.favorite.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        include: {
          restaurant: { select: { id: true, name: true, slug: true, logoUrl: true, city: true, district: true } },
          meal: {
            select: {
              id: true,
              name: true,
              imageUrl: true,
              price: true,
              currency: true,
              restaurant: { select: { id: true, name: true, slug: true } },
            },
          },
        },
      });
      return {
        favorites: favorites.map((favorite) => ({
          ...favorite,
          meal: favorite.meal ? { ...favorite.meal, price: Number(favorite.meal.price) } : null,
        })),
      };
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.post('/v1/favorites', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const parsed = favoriteSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });

      const targetExists = parsed.data.restaurantId
        ? await prisma.restaurant.findUnique({ where: { id: parsed.data.restaurantId }, select: { id: true } })
        : await prisma.meal.findUnique({ where: { id: parsed.data.mealId }, select: { id: true } });
      if (!targetExists) return reply.code(404).send({ error: 'FAVORITE_TARGET_NOT_FOUND' });

      const existing = await prisma.favorite.findFirst({
        where: { userId, restaurantId: parsed.data.restaurantId ?? null, mealId: parsed.data.mealId ?? null },
      });
      if (existing) return reply.code(200).send({ favorite: existing });

      const favorite = await prisma.favorite.create({
        data: { userId, restaurantId: parsed.data.restaurantId, mealId: parsed.data.mealId },
      });
      return reply.code(201).send({ favorite });
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.delete<{ Params: { id: string } }>('/v1/favorites/:id', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const deleted = await prisma.favorite.deleteMany({ where: { id: request.params.id, userId } });
      if (!deleted.count) return reply.code(404).send({ error: 'FAVORITE_NOT_FOUND' });
      return reply.code(204).send();
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });
};