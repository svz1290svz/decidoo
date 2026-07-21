import type { FastifyInstance, FastifyRequest } from 'fastify';
import { RestaurantStatus } from '@prisma/client';
import { z } from 'zod';
import { verifyAccessToken } from './auth.js';
import { prisma } from './db.js';

const requestSchema = z
  .object({
    city: z.string().trim().min(1).max(80).optional(),
    cuisine: z.string().trim().min(1).max(80).optional(),
    maxBudget: z.coerce.number().positive().max(100000).optional(),
    latitude: z.coerce.number().min(-90).max(90).optional(),
    longitude: z.coerce.number().min(-180).max(180).optional(),
    maxDistanceKm: z.coerce.number().positive().max(200).optional(),
    vegetarian: z.boolean().default(false),
    vegan: z.boolean().default(false),
    glutenFree: z.boolean().default(false),
    limit: z.coerce.number().int().min(1).max(20).default(10),
  })
  .refine(
    (value) => Boolean(value.latitude === undefined) === Boolean(value.longitude === undefined),
    { message: 'Latitude and longitude must be provided together.' },
  );

const optionalUserId = (request: FastifyRequest): string | null => {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) return null;
  try {
    return verifyAccessToken(header.slice(7).trim()).sub;
  } catch {
    return null;
  }
};

const radians = (degrees: number): number => (degrees * Math.PI) / 180;

const distanceKm = (
  latitude: number,
  longitude: number,
  targetLatitude: number,
  targetLongitude: number,
): number => {
  const earthRadiusKm = 6371;
  const latitudeDelta = radians(targetLatitude - latitude);
  const longitudeDelta = radians(targetLongitude - longitude);
  const a =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(radians(latitude)) *
      Math.cos(radians(targetLatitude)) *
      Math.sin(longitudeDelta / 2) ** 2;
  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

export const registerRecommendationRoutes = async (app: FastifyInstance): Promise<void> => {
  app.post('/v1/recommendations', async (request, reply) => {
    const parsed = requestSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
    }

    const {
      city,
      cuisine,
      maxBudget,
      latitude,
      longitude,
      maxDistanceKm,
      vegetarian,
      vegan,
      glutenFree,
      limit,
    } = parsed.data;

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
      take: 200,
      include: {
        restaurant: {
          select: {
            id: true,
            name: true,
            slug: true,
            city: true,
            district: true,
            latitude: true,
            longitude: true,
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
        const distance =
          latitude !== undefined && longitude !== undefined
            ? distanceKm(
                latitude,
                longitude,
                Number(meal.restaurant.latitude),
                Number(meal.restaurant.longitude),
              )
            : null;
        const proximityBonus = distance === null ? 0 : Math.max(0, 1 - distance / 20) * 0.5;
        const score = rating + reviewConfidence + verifiedBonus + sponsoredBonus + proximityBonus;
        const reasons = [
          maxBudget ? 'WITHIN_BUDGET' : null,
          cuisine ? 'CUISINE_MATCH' : null,
          vegetarian ? 'VEGETARIAN_MATCH' : null,
          vegan ? 'VEGAN_MATCH' : null,
          glutenFree ? 'GLUTEN_FREE_MATCH' : null,
          distance !== null && distance <= 5 ? 'NEARBY' : null,
          meal.restaurant.isVerified ? 'VERIFIED_RESTAURANT' : null,
          rating >= 4 ? 'HIGH_RATING' : null,
        ].filter((value): value is string => Boolean(value));

        return {
          score,
          distanceKm: distance === null ? null : Math.round(distance * 10) / 10,
          isSponsored: sponsored,
          boostId: meal.restaurant.boosts[0]?.id ?? null,
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
            id: meal.restaurant.id,
            name: meal.restaurant.name,
            slug: meal.restaurant.slug,
            city: meal.restaurant.city,
            district: meal.restaurant.district,
            averageRating: rating,
            reviewCount: meal.restaurant.reviewCount,
            isVerified: meal.restaurant.isVerified,
          },
        };
      })
      .filter((item) => maxDistanceKm === undefined || item.distanceKm === null || item.distanceKm <= maxDistanceKm)
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
      .map((item, index) => ({ ...item, rank: index + 1 }));

    const userId = optionalUserId(request);
    const session = await prisma.recommendationSession.create({
      data: {
        userId,
        latitude,
        longitude,
        budget: maxBudget,
        maxDistanceKm,
        requestContext: parsed.data,
      },
      select: { id: true },
    });

    if (ranked.length > 0) {
      await prisma.recommendationLog.createMany({
        data: ranked.map((item) => ({
          sessionId: session.id,
          userId,
          restaurantId: item.restaurant.id,
          mealId: item.meal.id,
          score: item.score,
          rank: item.rank,
          reasonCodes: item.reasons,
          explanation: item.disclosure,
          algorithmVersion: 'rules-v2-location',
          isSponsored: item.isSponsored,
          boostId: item.boostId,
        })),
      });
    }

    return {
      sessionId: session.id,
      algorithmVersion: 'rules-v2-location',
      sponsoredPolicy: 'Sponsored results receive a limited ranking bonus and are always disclosed.',
      results: ranked.map(({ boostId: _boostId, ...item }) => item),
    };
  });
};
