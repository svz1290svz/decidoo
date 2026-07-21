import { RestaurantStatus } from '@prisma/client';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { verifyAccessToken } from './auth.js';
import { prisma } from './db.js';

const moderationSchema = z.object({
  status: z.enum(['ACTIVE', 'REJECTED', 'SUSPENDED']),
  note: z.string().trim().max(500).optional(),
});

const adminFromRequest = (request: FastifyRequest): string => {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) throw new Error('UNAUTHORIZED');
  const claims = verifyAccessToken(header.slice(7).trim());
  if (claims.role !== 'ADMIN') throw new Error('FORBIDDEN');
  return claims.sub;
};

export const registerAdminRoutes = async (app: FastifyInstance): Promise<void> => {
  app.get('/v1/admin/restaurants', async (request, reply) => {
    try {
      adminFromRequest(request);
      const query = z.object({
        status: z.nativeEnum(RestaurantStatus).default(RestaurantStatus.PENDING_APPROVAL),
        limit: z.coerce.number().int().min(1).max(100).default(30),
        offset: z.coerce.number().int().min(0).default(0),
      }).safeParse(request.query);
      if (!query.success) return reply.code(400).send({ error: 'INVALID_QUERY', details: query.error.flatten() });

      const [restaurants, total] = await prisma.$transaction([
        prisma.restaurant.findMany({
          where: { status: query.data.status },
          take: query.data.limit,
          skip: query.data.offset,
          orderBy: { updatedAt: 'asc' },
          include: {
            members: {
              take: 1,
              include: { user: { select: { id: true, email: true, displayName: true } } },
            },
            _count: { select: { categories: true, meals: true } },
          },
        }),
        prisma.restaurant.count({ where: { status: query.data.status } }),
      ]);
      return { restaurants, pagination: { total, limit: query.data.limit, offset: query.data.offset } };
    } catch {
      return reply.code(403).send({ error: 'ADMIN_REQUIRED' });
    }
  });

  app.patch<{ Params: { id: string } }>('/v1/admin/restaurants/:id/moderate', async (request, reply) => {
    try {
      adminFromRequest(request);
      const parsed = moderationSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });

      const existing = await prisma.restaurant.findUnique({ where: { id: request.params.id } });
      if (!existing) return reply.code(404).send({ error: 'RESTAURANT_NOT_FOUND' });

      const restaurant = await prisma.restaurant.update({
        where: { id: existing.id },
        data: {
          status: parsed.data.status,
          isVerified: parsed.data.status === 'ACTIVE',
        },
      });
      return { restaurant, moderationNote: parsed.data.note ?? null };
    } catch {
      return reply.code(403).send({ error: 'ADMIN_REQUIRED' });
    }
  });
};
