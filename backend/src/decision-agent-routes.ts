import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from './db.js';
import { decideV6, type DecisionCandidateV6 } from './decision-engine-v6.js';

const weatherSchema = z.object({
  condition: z.string().trim().min(1).max(80).optional(),
  temperatureC: z.coerce.number().min(-80).max(70).optional(),
  precipitationProbability: z.coerce.number().min(0).max(1).optional(),
});

const requestSchema = z.object({
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
  weather: weatherSchema.optional(),
}).refine(
  (value) => Boolean(value.latitude === undefined) === Boolean(value.longitude === undefined),
  { message: 'Latitude and longitude must be provided together.' },
);

type RecommendationResponse = {
  sessionId: string;
  confidence: number;
  results: DecisionCandidateV6[];
};

export const registerDecisionAgentRoutes = async (app: FastifyInstance): Promise<void> => {
  app.post('/v1/decide', async (request, reply) => {
    const parsed = requestSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
    }

    const { weather, ...recommendationInput } = parsed.data;
    const authorization = request.headers.authorization;
    const injected = await app.inject({
      method: 'POST',
      url: '/v1/recommendations',
      headers: authorization ? { authorization } : undefined,
      payload: { ...recommendationInput, limit: 10 },
    });

    if (injected.statusCode >= 400) {
      const payload = injected.json();
      return reply.code(injected.statusCode).send(payload);
    }

    const recommendation = injected.json<RecommendationResponse>();
    const decision = decideV6(recommendation.results, weather);

    if (weather) {
      await prisma.recommendationSession.update({
        where: { id: recommendation.sessionId },
        data: { weatherContext: weather },
      });
    }

    return {
      sessionId: recommendation.sessionId,
      algorithmVersion: 'decision-engine-v6',
      decisionMode: decision.primary ? 'DECISIVE' : 'NO_MATCH',
      confidence: Math.round(decision.confidence * 100) / 100,
      context: { weather: weather ?? null },
      decision: decision.primary,
      alternatives: decision.alternatives,
      baseEngine: 'decision-engine-v5',
    };
  });
};
