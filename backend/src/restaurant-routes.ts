import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from './db.js';

const listQuery = z.object({
  city: z.string().trim().min(1).max(80).optional(),
  cuisine: z.string().trim().min(1).max(80).optional(),
  q: z.string().trim().min(1).max(120).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const registerRestaurantRoutes = async (app: FastifyInstance): Promise<void> => {
  app.get('/v1/restaurants', async (request, reply) => {
    const parsed = listQuery.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'INVALID_QUERY', details: parsed.error.flatten() });
    }

    const { city, cuisine, q, limit, offset } = parsed.data;
    const where = {
      status: 'ACTIVE' as const,
      ...(city ? { city: { equals: city, mode: 'insensitive' as const } } : {}),
      ...(q
        ? {
            OR: [
              { name: { contains: q, mode: 'insensitive' as const } },
              { description: { contains: q, mode: 'insensitive' as const } },
              { city: { contains: q, mode: 'insensitive' as const } },
            ],
          }
        : {}),
      ...(cuisine
        ? {
            meals: {
              some: {
                cuisine: { equals: cuisine, mode: 'insensitive' as const },
                isAvailable: true,
              },
            },
          }
        : {}),
    };

    const [restaurants, total] = await prisma.$transaction([
      prisma.restaurant.findMany({
        where,
        skip: offset,
        take: limit,
        orderBy: [{ isVerified: 'desc' }, { averageRating: 'desc' }, { reviewCount: 'desc' }],
        select: {
          id: true,
          name: true,
          slug: true,
          description: true,
          logoUrl: true,
          coverUrl: true,
          city: true,
          district: true,
          averageRating: true,
          reviewCount: true,
          isVerified: true,
          isOpen: true,
          meals: {
            where: { isAvailable: true },
            take: 4,
            orderBy: { createdAt: 'desc' },
            select: {
              id: true,
              name: true,
              imageUrl: true,
              price: true,
              currency: true,
              cuisine: true,
              tags: true,
            },
          },
        },
      }),
      prisma.restaurant.count({ where }),
    ]);

    return {
      restaurants: restaurants.map((restaurant) => ({
        ...restaurant,
        averageRating: Number(restaurant.averageRating),
        meals: restaurant.meals.map((meal) => ({ ...meal, price: Number(meal.price) })),
      })),
      pagination: { total, limit, offset, hasMore: offset + restaurants.length < total },
    };
  });

  app.get<{ Params: { slug: string } }>('/v1/restaurants/:slug', async (request, reply) => {
    const restaurant = await prisma.restaurant.findFirst({
      where: { slug: request.params.slug, status: 'ACTIVE' },
      include: {
        categories: {
          where: { isActive: true },
          orderBy: { sortOrder: 'asc' },
          include: {
            meals: {
              where: { isAvailable: true },
              orderBy: { name: 'asc' },
            },
          },
        },
      },
    });

    if (!restaurant) return reply.code(404).send({ error: 'RESTAURANT_NOT_FOUND' });

    return {
      restaurant: {
        ...restaurant,
        latitude: Number(restaurant.latitude),
        longitude: Number(restaurant.longitude),
        averageRating: Number(restaurant.averageRating),
        categories: restaurant.categories.map((category) => ({
          ...category,
          meals: category.meals.map((meal) => ({ ...meal, price: Number(meal.price) })),
        })),
      },
    };
  });
};
