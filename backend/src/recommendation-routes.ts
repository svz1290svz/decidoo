import type { FastifyInstance } from 'fastify';
import { RestaurantStatus } from '@prisma/client';
import { z } from 'zod';
import { prisma } from './db.js';

const requestSchema = z.object({
  city: z.string().trim().min(1).max(80).optional(),
  cuisine: z.string().trim().min(1).max(80).optional(),
  maxBudget: z.coerce.number().positive().max(100000).optional(),
  vegetarian: z.boolean().default(false),
  vegan: z.boolean().default(false),
  glutenFree: z.boolean().default(false),
  limit: z.coerce.number().int().min(1).max(20).default(10),
});

export const registerRecommendationRoutes = async (app: FastifyInstance): Promise<void> => {
  app.post('/v1/recommendations', async (request, reply) => {
    const parsed = requestSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
    }

    const { city, cuisine, maxBudget, vegetarian, vegan, glutenFree, limit } = parsed.data;
    const candidates = await prisma.meal.findMany({
      where: {
        isAvailable: true,
        ...(maxBudget ? { price: { lte: maxBudget } } : {}),
        ...(cuisine ? { cuisine: { equals: cuisine, mode: 'insensitive' } } : {}),
        ...(vegetarian ? { isVegetarian: true } : {}),
        ...(vegan ? { isVegan: true } : {}),
        ...(glutenFree ? { isGlutenFree: true } : {}),
        restaurant: {
          status: RestaurantStatus.ACTIVE,
          isOpen: true,
          ...(city ? { city: { equals: city, mode: 'insensitive' } } : {}),
        },
      },
      take: 100,
      include: {
        restaurant: {
          select: {
            id: true,
            name: true,
            slug: true,
            city: true,
            district: true,
            averageRating: true,
            reviewCount: true,
            isVerified: true,
            boosts: {
              where: { status: 'ACTIVE' },
              take: 1,
              select: { id: true },
            },
          },
        },
      },
    });

    const ranked = candidates
      .map((meal) => {
        const rating = Number(meal.restaurant.averageRating);
        const reviewConfidence = Math.min(meal.restaurant.reviewCount / 100, 1);
        const verifiedBonus = meal.restaurant.isVerified ? 0.35 : 0;
        const sponsored = meal.restaurant.boosts.length > 0;
        const sponsoredBonus = sponsored ? 0.15 : 0;
        const score = rating + reviewConfidence + verifiedBonus + sponsoredBonus;
        const reasons = [
          maxBudget ? 'WITHIN_BUDGET' : null,
          cuisine ? 'CUISINE_MATCH' : null,
          vegetarian ? 'VEGETARIAN_MATCH' : null,
          vegan ? 'VEGAN_MATCH' : null,
          glutenFree ? 'GLUTEN_FREE_MATCH' : null,
          meal.restaurant.isVerified ? 'VERIFIED_RESTAURANT' : null,
          rating >= 4 ? 'HIGH_RATING' : null,
        ].filter((value): value is string => Boolean(value));

        return {
          score,
          isSponsored: sponsored,
          disclosure: sponsored ? 'Sponsored placement influenced ranking.' : null,
          reasons,
          meal: {
            id: meal.id,
            name: meal.name,
            description: meal.description,
            imageUrl: meal.imageUrl,
            price: Number(meal.price),
            currency: meal.currency,
            cuisine: meal.cuisine,
            tags: meal.tags,
          },
          restaurant: {
            ...meal.restaurant,
            averageRating: rating,
            boosts: undefined,
          },
        };
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
      .map((item, index) => ({ ...item, rank: index + 1 }));

    return {
      algorithmVersion: 'rules-v1',
      sponsoredPolicy: 'Sponsored results receive a limited ranking bonus and are always disclosed.',
      results: ranked,
    };
  });
};
