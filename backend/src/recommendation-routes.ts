import type { FastifyInstance, FastifyRequest } from 'fastify';
import { RecommendationAction, RestaurantStatus } from '@prisma/client';
import { z } from 'zod';
import { verifyAccessToken } from './auth.js';
import { prisma } from './db.js';
import {
  confidenceV5,
  contextScoreV5,
  diversifyV5,
  freshnessScoreV5,
  isOpenAt,
} from './decision-engine-v5.js';
import {
  buildPersonalizationProfile,
  personalizationScore,
} from './personalization.js';

const requestSchema = z
  .object({
    city: z.string().trim().min(1).max(80).optional(),
    cuisine: z.string().trim().min(1).max(80).optional(),
    mealType: z.string().trim().min(1).max(80).optional(),
    mood: z.string().trim().min(1).max(80).optional(),
    hungerLevel: z.coerce.number().int().min(1).max(5).optional(),
    maxBudget: z.coerce.number().positive().max(100000).optional(),
    latitude: z.coerce.number().min(-90).max(90).optional(),
    longitude: z.coerce.number().min(-180).max(180).optional(),
    maxDistanceKm: z.coerce.number().positive().max(200).optional(),
    vegetarian: z.boolean().optional(),
    vegan: z.boolean().optional(),
    halalOnly: z.boolean().optional(),
    glutenFree: z.boolean().optional(),
    timezone: z.string().trim().min(1).max(80).optional(),
    limit: z.coerce.number().int().min(1).max(20).default(10),
  })
  .refine(
    (value) =>
      Boolean(value.latitude === undefined) ===
      Boolean(value.longitude === undefined),
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

export const distanceKm = (
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

const targetListMatches = (targets: string[], value: string | null): boolean =>
  targets.length === 0 ||
  (value !== null &&
    targets.some(
      (target) => target.trim().toLowerCase() === value.trim().toLowerCase(),
    ));

const inferredMealType = (now: Date, timezone: string): string => {
  const hour = Number(
    new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      hour: '2-digit',
      hourCycle: 'h23',
    }).format(now),
  );
  if (hour >= 5 && hour < 11) return 'Breakfast';
  if (hour >= 11 && hour < 15) return 'Lunch';
  if (hour >= 15 && hour < 22) return 'Dinner';
  return 'Late Night';
};

export const registerRecommendationRoutes = async (
  app: FastifyInstance,
): Promise<void> => {
  app.post('/v1/recommendations', async (request, reply) => {
    const parsed = requestSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply
        .code(400)
        .send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
    }

    const userId = optionalUserId(request);
    const now = new Date();
    const since = new Date(now.getTime() - 48 * 60 * 60 * 1000);

    const [preference, user, positiveSignals, negativeSignals, recentChoices] =
      userId
        ? await Promise.all([
            prisma.userPreference.findUnique({ where: { userId } }),
            prisma.user.findUnique({ where: { id: userId }, select: { timezone: true } }),
            prisma.recommendationLog.findMany({
              where: {
                userId,
                action: {
                  in: [
                    RecommendationAction.LIKED,
                    RecommendationAction.SAVED,
                    RecommendationAction.ORDER_CLICKED,
                    RecommendationAction.NAVIGATION_STARTED,
                  ],
                },
                mealId: { not: null },
              },
              orderBy: { actionAt: 'desc' },
              take: 100,
              select: {
                meal: { select: { cuisine: true, mealType: true, tags: true } },
              },
            }),
            prisma.recommendationLog.findMany({
              where: {
                userId,
                action: RecommendationAction.DISLIKED,
                mealId: { not: null },
              },
              orderBy: { actionAt: 'desc' },
              take: 100,
              select: {
                meal: { select: { cuisine: true, mealType: true, tags: true } },
              },
            }),
            prisma.recommendationLog.findMany({
              where: {
                userId,
                actionAt: { gte: since },
                action: {
                  in: [
                    RecommendationAction.ORDER_CLICKED,
                    RecommendationAction.NAVIGATION_STARTED,
                    RecommendationAction.LIKED,
                  ],
                },
                mealId: { not: null },
              },
              orderBy: { actionAt: 'desc' },
              take: 30,
              select: { mealId: true, meal: { select: { cuisine: true } } },
            }),
          ])
        : [null, null, [], [], []];

    const timezone = parsed.data.timezone ?? user?.timezone ?? 'UTC';
    let automaticMealType: string | undefined;
    try {
      automaticMealType = parsed.data.mealType ?? inferredMealType(now, timezone);
    } catch {
      return reply.code(400).send({ error: 'INVALID_TIMEZONE' });
    }

    const effective = {
      ...parsed.data,
      mealType: parsed.data.mealType,
      contextualMealType: automaticMealType,
      timezone,
      maxBudget:
        parsed.data.maxBudget ??
        (preference?.maxBudget == null ? undefined : Number(preference.maxBudget)),
      maxDistanceKm:
        parsed.data.maxDistanceKm ??
        (preference?.maxDistanceKm == null
          ? undefined
          : Number(preference.maxDistanceKm)),
      vegetarian: parsed.data.vegetarian ?? preference?.vegetarian ?? false,
      vegan: parsed.data.vegan ?? preference?.vegan ?? false,
      halalOnly: parsed.data.halalOnly ?? preference?.halalOnly ?? false,
      glutenFree: parsed.data.glutenFree ?? preference?.glutenFree ?? false,
    };

    const profile = buildPersonalizationProfile(
      preference,
      positiveSignals,
      negativeSignals,
    );
    const recentMealIds = new Set(
      recentChoices.map((choice) => choice.mealId).filter(Boolean),
    );
    const recentCuisines = new Set(
      recentChoices
        .map((choice) => choice.meal?.cuisine?.toLowerCase())
        .filter((value): value is string => Boolean(value)),
    );

    const candidates = await prisma.meal.findMany({
      where: {
        isAvailable: true,
        ...(effective.maxBudget ? { price: { lte: effective.maxBudget } } : {}),
        ...(effective.cuisine
          ? { cuisine: { equals: effective.cuisine, mode: 'insensitive' } }
          : {}),
        ...(parsed.data.mealType
          ? { mealType: { equals: parsed.data.mealType, mode: 'insensitive' } }
          : {}),
        ...(effective.vegetarian ? { isVegetarian: true } : {}),
        ...(effective.vegan ? { isVegan: true } : {}),
        ...(effective.glutenFree ? { isGlutenFree: true } : {}),
        ...(effective.halalOnly ? { isHalal: true } : {}),
        restaurant: {
          status: RestaurantStatus.ACTIVE,
          isOpen: true,
          ...(effective.city
            ? { city: { equals: effective.city, mode: 'insensitive' } }
            : {}),
        },
      },
      take: 300,
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
            monetizationCampaigns: {
              where: {
                status: 'ACTIVE',
                channel: 'SMART_CAMPAIGN',
                startsAt: { lte: now },
                endsAt: { gte: now },
                remainingBudget: { gt: 0 },
              },
              orderBy: { bidPerAction: 'desc' },
              take: 5,
              select: {
                id: true,
                targetRadiusKm: true,
                targetMealTypes: true,
                targetCuisines: true,
              },
            },
          },
        },
      },
    });

    const restaurantIds = [...new Set(candidates.map((meal) => meal.restaurant.id))];
    const operatingHours = restaurantIds.length
      ? await prisma.restaurantOperatingHour.findMany({
          where: { restaurantId: { in: restaurantIds } },
        })
      : [];
    const hoursByRestaurant = new Map<string, typeof operatingHours>();
    operatingHours.forEach((hour) => {
      const current = hoursByRestaurant.get(hour.restaurantId) ?? [];
      current.push(hour);
      hoursByRestaurant.set(hour.restaurantId, current);
    });

    const scored = candidates
      .map((meal) => {
        const hours = hoursByRestaurant.get(meal.restaurant.id) ?? [];
        if (!isOpenAt(hours, now, timezone)) return null;

        const personal = personalizationScore(meal, profile);
        if (personal.excluded) return null;
        const contextual = contextScoreV5(meal, {
          mood: effective.mood,
          hungerLevel: effective.hungerLevel,
          mealType: effective.contextualMealType,
        });
        const freshness = freshnessScoreV5(meal.updatedAt, now);
        const rating = Number(meal.restaurant.averageRating);
        const reviewConfidence = Math.min(
          Math.log10(meal.restaurant.reviewCount + 1) / 2,
          1,
        );
        const verifiedBonus = meal.restaurant.isVerified ? 0.3 : 0;
        const distance =
          effective.latitude !== undefined && effective.longitude !== undefined
            ? distanceKm(
                effective.latitude,
                effective.longitude,
                Number(meal.restaurant.latitude),
                Number(meal.restaurant.longitude),
              )
            : null;

        const smartCampaign = meal.restaurant.monetizationCampaigns.find(
          (campaign) => {
            if (
              !targetListMatches(campaign.targetCuisines, meal.cuisine) ||
              !targetListMatches(campaign.targetMealTypes, meal.mealType)
            ) {
              return false;
            }
            if (campaign.targetRadiusKm !== null) {
              if (distance === null) return false;
              if (distance > Number(campaign.targetRadiusKm)) return false;
            }
            return true;
          },
        );

        const legacyBoost = meal.restaurant.boosts[0]?.id ?? null;
        const sponsored = legacyBoost !== null || smartCampaign !== undefined;
        const sponsoredBonus = sponsored ? 0.12 : 0;
        const proximityBonus =
          distance === null ? 0 : Math.max(0, 1 - distance / 25) * 0.65;
        const budgetFitBonus = effective.maxBudget
          ? Math.max(0, 1 - Number(meal.price) / effective.maxBudget) * 0.25
          : 0;
        const repeatPenalty = recentMealIds.has(meal.id)
          ? 0.6
          : meal.cuisine && recentCuisines.has(meal.cuisine.toLowerCase())
            ? 0.18
            : 0;
        const score =
          rating +
          reviewConfidence +
          verifiedBonus +
          sponsoredBonus +
          proximityBonus +
          budgetFitBonus +
          personal.score +
          contextual.score +
          freshness.score -
          repeatPenalty;

        const reasons = [
          effective.maxBudget ? 'WITHIN_BUDGET' : null,
          effective.cuisine ? 'CUISINE_MATCH' : null,
          parsed.data.mealType ? 'MEAL_TYPE_MATCH' : 'TIME_CONTEXT_MATCH',
          effective.vegetarian ? 'VEGETARIAN_MATCH' : null,
          effective.vegan ? 'VEGAN_MATCH' : null,
          effective.halalOnly ? 'HALAL_MATCH' : null,
          effective.glutenFree ? 'GLUTEN_FREE_MATCH' : null,
          distance !== null && distance <= 5 ? 'NEARBY' : null,
          meal.restaurant.isVerified ? 'VERIFIED_RESTAURANT' : null,
          rating >= 4 ? 'HIGH_RATING' : null,
          freshness.stale ? 'MENU_STALE_PENALTY' : 'MENU_FRESHNESS',
          repeatPenalty > 0 ? 'RECENT_CHOICE_PENALTY' : null,
          smartCampaign ? `SMART_CAMPAIGN:${smartCampaign.id}` : null,
          ...personal.reasons,
          ...contextual.reasons,
        ].filter((value): value is string => Boolean(value));

        return {
          score,
          distanceKm: distance === null ? null : Math.round(distance * 10) / 10,
          isSponsored: sponsored,
          boostId: legacyBoost,
          disclosure: sponsored
            ? 'Sponsored placement influenced ranking within a strict limit.'
            : null,
          reasons,
          meal: {
            id: meal.id,
            name: meal.name,
            description: meal.description,
            imageUrl: meal.imageUrl,
            price: Number(meal.price),
            currency: meal.currency,
            cuisine: meal.cuisine,
            mealType: meal.mealType,
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
      .filter((item): item is NonNullable<typeof item> => item !== null)
      .filter(
        (item) =>
          effective.maxDistanceKm === undefined ||
          item.distanceKm === null ||
          item.distanceKm <= effective.maxDistanceKm,
      )
      .sort((a, b) => b.score - a.score);

    const ranked = diversifyV5(scored, effective.limit).map((item, index) => ({
      ...item,
      rank: index + 1,
    }));
    const confidence = confidenceV5(ranked.map((item) => item.score));

    const session = await prisma.recommendationSession.create({
      data: {
        userId,
        latitude: effective.latitude,
        longitude: effective.longitude,
        budget: effective.maxBudget,
        maxDistanceKm: effective.maxDistanceKm,
        hungerLevel: effective.hungerLevel,
        mood: effective.mood,
        mealType: effective.contextualMealType,
        requestContext: effective,
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
          algorithmVersion: 'decision-engine-v5',
          isSponsored: item.isSponsored,
          boostId: item.boostId,
        })),
      });
    }

    return {
      sessionId: session.id,
      algorithmVersion: 'decision-engine-v5',
      personalized: Boolean(
        userId &&
          (preference || positiveSignals.length > 0 || negativeSignals.length > 0),
      ),
      confidence: Math.round(confidence * 100) / 100,
      decisionMode: confidence >= 0.72 ? 'DECISIVE' : 'EXPLORE',
      context: {
        mealType: effective.contextualMealType,
        timezone,
      },
      sponsoredPolicy:
        'Sponsored results receive a small capped bonus, require targeting eligibility and are always disclosed.',
      results: ranked.map(({ boostId: _boostId, reasons, ...item }) => ({
        ...item,
        reasons: reasons.filter(
          (reason) => !reason.startsWith('SMART_CAMPAIGN:'),
        ),
      })),
    };
  });
};
