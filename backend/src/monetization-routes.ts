import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from './db.js';
import { requireAuth } from './security.js';
import { canBillAction, normalizeCountry, normalizeCurrency, sponsoredDisclosure } from './monetization-domain.js';

const campaignSchema = z.object({
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
}).refine((v) => v.endsAt > v.startsAt, 'endsAt must be after startsAt');

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

async function assertOwner(userId: string, restaurantId: string): Promise<void> {
  const member = await prisma.restaurantMember.findFirst({ where: { userId, restaurantId } });
  if (!member) throw Object.assign(new Error('FORBIDDEN'), { statusCode: 403 });
}

export async function registerMonetizationRoutes(app: FastifyInstance): Promise<void> {
  app.get('/v1/monetization/plans', async (request) => ({
    currency: normalizeCurrency(String((request.query as Record<string, unknown>).currency ?? 'USD')),
    channels: [
      { code: 'BOOST', pricing: 'budget', disclosure: sponsoredDisclosure('en') },
      { code: 'PER_ACTION', pricing: 'verified_action' },
      { code: 'PRO_SUBSCRIPTION', pricing: 'recurring' },
      { code: 'SMART_CAMPAIGN', pricing: 'budget_and_action' },
    ],
  }));

  app.post('/v1/owner/monetization/campaigns', { preHandler: requireAuth }, async (request, reply) => {
    const body = campaignSchema.parse(request.body);
    await assertOwner(request.user!.id, body.restaurantId);
    const campaign = await prisma.monetizationCampaign.create({ data: {
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
    }});
    return reply.code(201).send(campaign);
  });

  app.get('/v1/owner/monetization/campaigns/:restaurantId', { preHandler: requireAuth }, async (request) => {
    const restaurantId = (request.params as { restaurantId: string }).restaurantId;
    await assertOwner(request.user!.id, restaurantId);
    return prisma.monetizationCampaign.findMany({ where: { restaurantId }, orderBy: { createdAt: 'desc' } });
  });

  app.post('/v1/owner/monetization/subscriptions', { preHandler: requireAuth }, async (request, reply) => {
    const body = subscriptionSchema.parse(request.body);
    await assertOwner(request.user!.id, body.restaurantId);
    const subscription = await prisma.restaurantSubscription.upsert({
      where: { restaurantId: body.restaurantId },
      update: { planCode: body.planCode, currency: normalizeCurrency(body.currency), countryCode: normalizeCountry(body.countryCode), status: 'PENDING' },
      create: { restaurantId: body.restaurantId, planCode: body.planCode, currency: normalizeCurrency(body.currency), countryCode: normalizeCountry(body.countryCode) },
    });
    return reply.code(201).send(subscription);
  });

  app.post('/v1/monetization/actions', { preHandler: requireAuth }, async (request, reply) => {
    const body = actionSchema.parse(request.body);
    if (!canBillAction(body.action)) return reply.code(400).send({ error: 'NON_BILLABLE_ACTION' });
    const log = await prisma.recommendationLog.findUnique({ where: { id: body.recommendationLogId } });
    if (!log) return reply.code(404).send({ error: 'RECOMMENDATION_NOT_FOUND' });
    const existing = await prisma.billableAction.findUnique({ where: { idempotencyKey: body.idempotencyKey } });
    if (existing) return existing;
    const action = await prisma.billableAction.create({ data: {
      restaurantId: log.restaurantId,
      recommendationLogId: log.id,
      action: body.action,
      idempotencyKey: body.idempotencyKey,
      verified: true,
    }});
    return reply.code(201).send(action);
  });

  app.get('/v1/owner/monetization/roi/:restaurantId', { preHandler: requireAuth }, async (request) => {
    const restaurantId = (request.params as { restaurantId: string }).restaurantId;
    await assertOwner(request.user!.id, restaurantId);
    const [campaigns, actions, ledger] = await Promise.all([
      prisma.monetizationCampaign.findMany({ where: { restaurantId } }),
      prisma.billableAction.count({ where: { restaurantId, verified: true } }),
      prisma.billingLedger.aggregate({ where: { restaurantId }, _sum: { amount: true } }),
    ]);
    return { campaigns, verifiedActions: actions, totalCharged: ledger._sum.amount ?? 0 };
  });
}
