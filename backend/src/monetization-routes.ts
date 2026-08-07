import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { verifyAccessToken } from './auth.js';
import { prisma } from './db.js';
import {
  canBillAction,
  normalizeCountry,
  normalizeCurrency,
  sponsoredDisclosure,
} from './monetization-domain.js';

const campaignSchema = z
  .object({
    restaurantId: z.string().min(1),
    name: z.string().min(2).max(120),
    channel: z.enum(['BOOST', 'PER_ACTION', 'SMART_CAMPAIGN']),
    budget: z.number().positive().max(1_000_000),
    currency: z.string().length(3),
    countryCode: z.string().length(2),
    startsAt: z.coerce.date(),
    endsAt: z.coerce.date(),
    targetRadiusKm: z.number().positive().max(100).optional(),
    targetMealTypes: z.array(z.string().max(50)).max(20).default([]),
    targetCuisines: z.array(z.string().max(50)).max(20).default([]),
    bidPerAction: z.number().positive().max(10_000).optional(),
  })
  .refine((value) => value.endsAt > value.startsAt, 'endsAt must be after startsAt');

const subscriptionSchema = z.object({
  restaurantId: z.string().min(1),
  planCode: z.enum(['PRO_MONTHLY', 'PRO_ANNUAL']),
  currency: z.string().length(3),
  countryCode: z.string().length(2),
});

const actionSchema = z.object({
  recommendationLogId: z.string().min(1),
  action: z.enum(['RESTAURANT_OPENED', 'NAVIGATION_STARTED', 'ORDER_CLICKED']),
  idempotencyKey: z.string().min(12).max(200),
});

const userIdFromRequest = (request: FastifyRequest): string => {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) throw new Error('UNAUTHORIZED');
  return verifyAccessToken(header.slice(7).trim()).sub;
};

async function assertOwner(userId: string, restaurantId: string): Promise<void> {
  const member = await prisma.restaurantMember.findUnique({
    where: { userId_restaurantId: { userId, restaurantId } },
    select: { id: true },
  });
  if (!member) throw new Error('FORBIDDEN');
}

export async function registerMonetizationRoutes(app: FastifyInstance): Promise<void> {
  app.get('/v1/monetization/plans', async (request) => ({
    currency: normalizeCurrency(
      String((request.query as Record<string, unknown>).currency ?? 'USD'),
    ),
    channels: [
      { code: 'BOOST', pricing: 'budget', disclosure: sponsoredDisclosure('en') },
      { code: 'PER_ACTION', pricing: 'verified_action' },
      { code: 'PRO_SUBSCRIPTION', pricing: 'recurring' },
      { code: 'SMART_CAMPAIGN', pricing: 'budget_and_action' },
    ],
  }));

  app.post('/v1/owner/monetization/campaigns', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const parsed = campaignSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
      }
      const body = parsed.data;
      await assertOwner(userId, body.restaurantId);
      const campaign = await prisma.monetizationCampaign.create({
        data: {
          restaurantId: body.restaurantId,
          name: body.name,
          channel: body.channel,
          budget: body.budget,
          remainingBudget: body.budget,
          currency: normalizeCurrency(body.currency),
          countryCode: normalizeCountry(body.countryCode),
          startsAt: body.startsAt,
          endsAt: body.endsAt,
          targetRadiusKm: body.targetRadiusKm,
          targetMealTypes: body.targetMealTypes,
          targetCuisines: body.targetCuisines,
          bidPerAction: body.bidPerAction,
        },
      });
      return reply.code(201).send({ campaign });
    } catch (error) {
      if (error instanceof Error && error.message === 'FORBIDDEN') {
        return reply.code(403).send({ error: 'FORBIDDEN' });
      }
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.get('/v1/owner/monetization/campaigns/:restaurantId', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const restaurantId = (request.params as { restaurantId: string }).restaurantId;
      await assertOwner(userId, restaurantId);
      const campaigns = await prisma.monetizationCampaign.findMany({
        where: { restaurantId },
        orderBy: { createdAt: 'desc' },
      });
      return { campaigns };
    } catch (error) {
      if (error instanceof Error && error.message === 'FORBIDDEN') {
        return reply.code(403).send({ error: 'FORBIDDEN' });
      }
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.post('/v1/owner/monetization/subscriptions', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const parsed = subscriptionSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
      }
      const body = parsed.data;
      await assertOwner(userId, body.restaurantId);
      const subscription = await prisma.restaurantSubscription.upsert({
        where: { restaurantId: body.restaurantId },
        update: {
          planCode: body.planCode,
          currency: normalizeCurrency(body.currency),
          countryCode: normalizeCountry(body.countryCode),
          status: 'PENDING',
        },
        create: {
          restaurantId: body.restaurantId,
          planCode: body.planCode,
          currency: normalizeCurrency(body.currency),
          countryCode: normalizeCountry(body.countryCode),
        },
      });
      return reply.code(201).send({ subscription });
    } catch (error) {
      if (error instanceof Error && error.message === 'FORBIDDEN') {
        return reply.code(403).send({ error: 'FORBIDDEN' });
      }
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.post('/v1/monetization/actions', async (request, reply) => {
    try {
      userIdFromRequest(request);
      const parsed = actionSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
      }
      const body = parsed.data;
      if (!canBillAction(body.action)) {
        return reply.code(400).send({ error: 'NON_BILLABLE_ACTION' });
      }
      const log = await prisma.recommendationLog.findUnique({
        where: { id: body.recommendationLogId },
      });
      if (!log) return reply.code(404).send({ error: 'RECOMMENDATION_NOT_FOUND' });
      const existing = await prisma.billableAction.findUnique({
        where: { idempotencyKey: body.idempotencyKey },
      });
      if (existing) return { action: existing, duplicate: true };
      const action = await prisma.billableAction.create({
        data: {
          restaurantId: log.restaurantId,
          recommendationLogId: log.id,
          action: body.action,
          idempotencyKey: body.idempotencyKey,
          verified: true,
        },
      });
      return reply.code(201).send({ action, duplicate: false });
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.get('/v1/owner/monetization/roi/:restaurantId', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const restaurantId = (request.params as { restaurantId: string }).restaurantId;
      await assertOwner(userId, restaurantId);
      const [campaigns, actions, ledger] = await Promise.all([
        prisma.monetizationCampaign.findMany({ where: { restaurantId } }),
        prisma.billableAction.count({ where: { restaurantId, verified: true } }),
        prisma.billingLedger.aggregate({
          where: { restaurantId },
          _sum: { amount: true },
        }),
      ]);
      return {
        campaigns,
        verifiedActions: actions,
        totalCharged: ledger._sum.amount ?? 0,
      };
    } catch (error) {
      if (error instanceof Error && error.message === 'FORBIDDEN') {
        return reply.code(403).send({ error: 'FORBIDDEN' });
      }
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });
}
