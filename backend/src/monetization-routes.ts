import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { verifyAccessToken } from './auth.js';
import { prisma } from './db.js';
import { selectChargeCampaign } from './monetization-billing.js';
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
  .refine((value) => value.endsAt > value.startsAt, 'endsAt must be after startsAt')
  .refine(
    (value) => value.channel === 'BOOST' || value.bidPerAction !== undefined,
    'bidPerAction is required for performance campaigns',
  );

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

const campaignStatusSchema = z.object({
  status: z.enum(['PAUSED', 'CANCELLED', 'ACTIVE']),
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
      { code: 'BOOST', pricing: 'prepaid_budget', disclosure: sponsoredDisclosure('en') },
      { code: 'PER_ACTION', pricing: 'verified_action_postpaid' },
      { code: 'PRO_SUBSCRIPTION', pricing: 'recurring' },
      { code: 'SMART_CAMPAIGN', pricing: 'funded_budget_and_action' },
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
          status: body.channel === 'PER_ACTION' ? 'ACTIVE' : 'PENDING_PAYMENT',
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
      return reply.code(201).send({
        campaign,
        paymentRequired: body.channel !== 'PER_ACTION',
      });
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

  app.patch('/v1/owner/monetization/campaigns/:campaignId/status', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const campaignId = (request.params as { campaignId: string }).campaignId;
      const parsed = campaignStatusSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT' });
      const campaign = await prisma.monetizationCampaign.findUnique({ where: { id: campaignId } });
      if (!campaign) return reply.code(404).send({ error: 'CAMPAIGN_NOT_FOUND' });
      await assertOwner(userId, campaign.restaurantId);
      if (parsed.data.status === 'ACTIVE' && campaign.channel !== 'PER_ACTION' && campaign.status === 'PENDING_PAYMENT') {
        return reply.code(409).send({ error: 'PAYMENT_REQUIRED' });
      }
      const updated = await prisma.monetizationCampaign.update({
        where: { id: campaignId },
        data: { status: parsed.data.status },
      });
      return { campaign: updated };
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
      return reply.code(201).send({ subscription, paymentRequired: true });
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

      const result = await prisma.$transaction(async (tx) => {
        const existing = await tx.billableAction.findUnique({
          where: { idempotencyKey: body.idempotencyKey },
        });
        if (existing) return { action: existing, duplicate: true, charged: false };

        const log = await tx.recommendationLog.findUnique({
          where: { id: body.recommendationLogId },
        });
        if (!log) throw new Error('RECOMMENDATION_NOT_FOUND');

        const now = new Date();
        const campaigns = await tx.monetizationCampaign.findMany({
          where: {
            restaurantId: log.restaurantId,
            status: 'ACTIVE',
            startsAt: { lte: now },
            endsAt: { gte: now },
            channel: { in: ['PER_ACTION', 'SMART_CAMPAIGN'] },
            remainingBudget: { gt: 0 },
          },
        });
        const decision = selectChargeCampaign(campaigns, body.action, now);

        let charged = false;
        if (decision) {
          const updated = await tx.monetizationCampaign.updateMany({
            where: {
              id: decision.campaignId,
              status: 'ACTIVE',
              remainingBudget: { gte: decision.amount },
            },
            data: { remainingBudget: { decrement: decision.amount } },
          });
          charged = updated.count === 1;
        }

        const action = await tx.billableAction.create({
          data: {
            restaurantId: log.restaurantId,
            recommendationLogId: log.id,
            action: body.action,
            idempotencyKey: body.idempotencyKey,
            verified: true,
            amount: charged && decision ? decision.amount : undefined,
            currency: charged && decision ? decision.currency : undefined,
            billedAt: charged ? now : undefined,
          },
        });

        if (charged && decision) {
          await tx.billingLedger.create({
            data: {
              restaurantId: log.restaurantId,
              campaignId: decision.campaignId,
              entryType: 'CHARGE',
              amount: decision.amount,
              currency: decision.currency,
              referenceType: 'BILLABLE_ACTION',
              referenceId: action.id,
              idempotencyKey: `charge:${body.idempotencyKey}`,
            },
          });
        }

        return { action, duplicate: false, charged };
      });

      return reply.code(result.duplicate ? 200 : 201).send(result);
    } catch (error) {
      if (error instanceof Error && error.message === 'RECOMMENDATION_NOT_FOUND') {
        return reply.code(404).send({ error: 'RECOMMENDATION_NOT_FOUND' });
      }
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.get('/v1/owner/monetization/roi/:restaurantId', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const restaurantId = (request.params as { restaurantId: string }).restaurantId;
      await assertOwner(userId, restaurantId);
      const [campaigns, actions, chargedActions, ledger] = await Promise.all([
        prisma.monetizationCampaign.findMany({ where: { restaurantId } }),
        prisma.billableAction.count({ where: { restaurantId, verified: true } }),
        prisma.billableAction.count({ where: { restaurantId, billedAt: { not: null } } }),
        prisma.billingLedger.aggregate({
          where: { restaurantId },
          _sum: { amount: true },
        }),
      ]);
      return {
        campaigns,
        verifiedActions: actions,
        chargedActions,
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
