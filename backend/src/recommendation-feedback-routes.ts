import type { FastifyInstance, FastifyRequest } from 'fastify';
import { RecommendationAction } from '@prisma/client';
import { z } from 'zod';
import { verifyAccessToken } from './auth.js';
import { prisma } from './db.js';

const feedbackSchema = z.object({
  recommendationLogId: z.string().cuid(),
  action: z.nativeEnum(RecommendationAction),
});

const authenticatedUserId = (request: FastifyRequest): string => {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) throw new Error('AUTH_REQUIRED');
  return verifyAccessToken(header.slice(7).trim()).sub;
};

export const registerRecommendationFeedbackRoutes = async (
  app: FastifyInstance,
): Promise<void> => {
  app.post('/v1/recommendations/feedback', async (request, reply) => {
    let userId: string;
    try {
      userId = authenticatedUserId(request);
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }

    const parsed = feedbackSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({
        error: 'INVALID_INPUT',
        details: parsed.error.flatten(),
      });
    }

    const existing = await prisma.recommendationLog.findFirst({
      where: {
        id: parsed.data.recommendationLogId,
        userId,
      },
      select: { id: true },
    });
    if (!existing) {
      return reply.code(404).send({ error: 'RECOMMENDATION_NOT_FOUND' });
    }

    const feedback = await prisma.recommendationLog.update({
      where: { id: existing.id },
      data: {
        action: parsed.data.action,
        actionAt: new Date(),
      },
      select: {
        id: true,
        action: true,
        actionAt: true,
      },
    });

    return { feedback };
  });
};
