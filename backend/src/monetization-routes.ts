import type { FastifyInstance, FastifyRequest } from 'fastify';
import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { verifyAccessToken } from './auth.js';
import { env } from './config.js';
import { prisma } from './db.js';
import {
  selectChargeCampaign,
  smartCampaignIdFromReasons,
} from './monetization-billing.js';
import {
  canBillAction,
  normalizeCountry,
  normalizeCurrency,
  sponsoredDisclosure,
} from './monetization-domain.js';
import {
  campaignStatusForConfirmation,
  secureSecretMatches,
  subscriptionStatusForConfirmation,
} from './payment-confirmation.js';

const campaignSchema = z
  .object({
    restaurantId: z.string().min(1),
    name: z.string().trim().min(2).max(120),
    channel: z.enum(['BOOST', 'PER_ACTION', 'SMART_CAMPAIGN']),
    budget: z.coerce.number().positive().max(1_000_000),
    currency: z.string().trim().length(3),
    countryCode: z.string().trim().length(2),
    startsAt: z.coerce.date(),
    endsAt: z.coerce.date(),
    targetRadiusKm: z.coerce.number().positive().max(100).optional(),
    targetMealTypes: z.array(z.string().trim().max(50)).max(20).default([]),
    targetCuisines: z.array(z.string().trim().max(50)).max(20).default([]),
    bidPerAction: z.coerce.number().positive().max(10_000).optional(),
  })
  .refine((value) => value.endsAt > value.startsAt, {
    message: 'endsAt must be after startsAt',
  })
  .refine(
    (value) => value.channel === 'BOOST' || value.bidPerAction !== undefined,
    { message: 'bidPerAction is required for performance campaigns' },
  );

const subscriptionSchema = z.object({
  restaurantId: z.string().min(1),
  planCode: z.enum(['PRO_MONTHLY', 'PRO_ANNUAL']),
  currency: z.string().trim().length(3),
  countryCode: z.string().trim().length(2),
});

const actionSchema = z
  .object({
    recommendationLogId: z.string().min(1).optional(),
    sessionId: z.string().min(1).optional(),
    restaurantId: z.string().min(1).optional(),
    mealId: z.string().min(1).optional(),
    action: z.enum([
      'RESTAURANT_OPENED',
      'NAVIGATION_STARTED',
      'ORDER_CLICKED',
    ]),
    idempotencyKey: z.string().min(12).max(200),
  })
  .refine(
    (value) =>
      Boolean(value.recommendationLogId) ||
      Boolean(value.sessionId && value.restaurantId),
    { message: 'Recommendation attribution is required.' },
  );

const campaignStatusSchema = z.object({
  status: z.enum(['PAUSED', 'CANCELLED', 'ACTIVE']),
});

const paymentConfirmationSchema = z.union([
  z.object({
    type: z.enum(['CAMPAIGN_PAID', 'CAMPAIGN_REFUNDED']),
    campaignId: z.string().min(1),
    transactionId: z.string().min(1),
    provider: z.string().trim().min(1).max(80),
    externalPaymentId: z.string().trim().min(1).max(200),
  }),
  z.object({
    type: z.enum([
      'SUBSCRIPTION_ACTIVE',
      'SUBSCRIPTION_PAST_DUE',
      'SUBSCRIPTION_CANCELLED',
    ]),
    restaurantId: z.string().min(1),
    provider: z.string().trim().min(1).max(80),
    externalSubscriptionId: z.string().trim().min(1).max(200).optional(),
    currentPeriodStart: z.coerce.date().optional(),
    currentPeriodEnd: z.coerce.date().optional(),
  }),
]);

const userIdFromRequest = (request: FastifyRequest): string => {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) throw new Error('UNAUTHORIZED');
  return verifyAccessToken(header.slice(7).trim()).sub;
};

const assertOwner = async (
  userId: string,
  restaurantId: string,
): Promise<void> => {
  const member = await prisma.restaurantMember.findUnique({
    where: { userId_restaurantId: { userId, restaurantId } },
    select: { id: true },
  });
  if (!member) throw new Error('FORBIDDEN');
};

export async function registerMonetizationRoutes(
  app: FastifyInstance,
): Promise<void> {
  app.get('/v1/monetization/plans', async (request) => ({
    currency: normalizeCurrency(
      String((request.query as Record<string, unknown>).currency ?? 'USD'),
    ),
    channels: [
      {
        code: 'BOOST',
        pricing: 'prepaid_budget',
        disclosure: sponsoredDisclosure('en'),
      },
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
        return reply.code(400).send({
          error: 'INVALID_INPUT',
          details: parsed.error.flatten(),
        });
      }
      const body = parsed.data;
      await assertOwner(userId, body.restaurantId);
      const campaign = await prisma.monetizationCampaign.create({
        data: {
          restaurantId: body.restaurantId,
          name: body.name,
          channel: body.channel,
          status:
            body.channel === 'PER_ACTION' ? 'ACTIVE' : 'PENDING_PAYMENT',
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

  app.get(
    '/v1/owner/monetization/campaigns/:restaurantId',
    async (request, reply) => {
      try {
        const userId = userIdFromRequest(request);
        const restaurantId = (request.params as { restaurantId: string })
          .restaurantId;
        await assertOwner(userId, restaurantId);
        return {
          campaigns: await prisma.monetizationCampaign.findMany({
            where: { restaurantId },
            orderBy: { createdAt: 'desc' },
          }),
        };
      } catch (error) {
        if (error instanceof Error && error.message === 'FORBIDDEN') {
          return reply.code(403).send({ error: 'FORBIDDEN' });
        }
        return reply.code(401).send({ error: 'AUTH_REQUIRED' });
      }
    },
  );

  app.patch(
    '/v1/owner/monetization/campaigns/:campaignId/status',
    async (request, reply) => {
      try {
        const userId = userIdFromRequest(request);
        const campaignId = (request.params as { campaignId: string })
          .campaignId;
        const parsed = campaignStatusSchema.safeParse(request.body);
        if (!parsed.success) {
          return reply.code(400).send({ error: 'INVALID_INPUT' });
        }
        const campaign = await prisma.monetizationCampaign.findUnique({
          where: { id: campaignId },
        });
        if (!campaign) {
          return reply.code(404).send({ error: 'CAMPAIGN_NOT_FOUND' });
        }
        await assertOwner(userId, campaign.restaurantId);
        if (
          parsed.data.status === 'ACTIVE' &&
          campaign.channel !== 'PER_ACTION' &&
          campaign.status === 'PENDING_PAYMENT'
        ) {
          return reply.code(409).send({ error: 'PAYMENT_REQUIRED' });
        }
        return {
          campaign: await prisma.monetizationCampaign.update({
            where: { id: campaignId },
            data: { status: parsed.data.status },
          }),
        };
      } catch (error) {
        if (error instanceof Error && error.message === 'FORBIDDEN') {
          return reply.code(403).send({ error: 'FORBIDDEN' });
        }
        return reply.code(401).send({ error: 'AUTH_REQUIRED' });
      }
    },
  );

  app.post(
    '/v1/owner/monetization/campaigns/:campaignId/payment-intent',
    async (request, reply) => {
      try {
        const userId = userIdFromRequest(request);
        const campaignId = (request.params as { campaignId: string })
          .campaignId;
        const campaign = await prisma.monetizationCampaign.findUnique({
          where: { id: campaignId },
        });
        if (!campaign) {
          return reply.code(404).send({ error: 'CAMPAIGN_NOT_FOUND' });
        }
        await assertOwner(userId, campaign.restaurantId);
        if (campaign.channel === 'PER_ACTION') {
          return reply.code(409).send({ error: 'PREPAYMENT_NOT_REQUIRED' });
        }
        if (campaign.status !== 'PENDING_PAYMENT') {
          return reply
            .code(409)
            .send({ error: 'CAMPAIGN_NOT_AWAITING_PAYMENT' });
        }
        const previous = await prisma.paymentTransaction.findFirst({
          where: {
            restaurantId: campaign.restaurantId,
            status: 'PENDING',
            metadata: { path: ['campaignId'], equals: campaign.id },
          },
          orderBy: { createdAt: 'desc' },
        });
        const transaction =
          previous ??
          (await prisma.paymentTransaction.create({
            data: {
              restaurantId: campaign.restaurantId,
              amount: campaign.budget,
              currency: campaign.currency,
              status: 'PENDING',
              provider: 'EXTERNAL_GATEWAY',
              metadata: {
                purpose: 'CAMPAIGN_FUNDING',
                campaignId: campaign.id,
              },
            },
          }));
        return reply.code(previous ? 200 : 201).send({
          transaction,
          providerContract: {
            reference: transaction.id,
            purpose: 'CAMPAIGN_FUNDING',
            amount: Number(campaign.budget),
            currency: campaign.currency,
            countryCode: campaign.countryCode,
          },
        });
      } catch (error) {
        if (error instanceof Error && error.message === 'FORBIDDEN') {
          return reply.code(403).send({ error: 'FORBIDDEN' });
        }
        return reply.code(401).send({ error: 'AUTH_REQUIRED' });
      }
    },
  );

  app.post('/v1/owner/monetization/subscriptions', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const parsed = subscriptionSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({
          error: 'INVALID_INPUT',
          details: parsed.error.flatten(),
        });
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
      return reply.code(201).send({
        subscription,
        paymentRequired: true,
        providerContract: {
          reference: subscription.id,
          purpose: 'PRO_SUBSCRIPTION',
          planCode: subscription.planCode,
          currency: subscription.currency,
          countryCode: subscription.countryCode,
        },
      });
    } catch (error) {
      if (error instanceof Error && error.message === 'FORBIDDEN') {
        return reply.code(403).send({ error: 'FORBIDDEN' });
      }
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.post(
    '/v1/internal/monetization/payment-confirmations',
    async (request, reply) => {
      const providedSecret = request.headers['x-decidoo-payment-secret'];
      const secret = Array.isArray(providedSecret)
        ? providedSecret[0]
        : providedSecret;
      if (!env.PAYMENT_CONFIRMATION_SECRET) {
        return reply
          .code(503)
          .send({ error: 'PAYMENT_PROVIDER_NOT_CONFIGURED' });
      }
      if (!secureSecretMatches(secret, env.PAYMENT_CONFIRMATION_SECRET)) {
        return reply.code(401).send({ error: 'INVALID_PAYMENT_SIGNATURE' });
      }
      const parsed = paymentConfirmationSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({
          error: 'INVALID_INPUT',
          details: parsed.error.flatten(),
        });
      }
      const event = parsed.data;
      try {
        const campaignStatus = campaignStatusForConfirmation(event.type);
        if (campaignStatus && 'campaignId' in event) {
          const result = await prisma.$transaction(async (tx) => {
            const campaign = await tx.monetizationCampaign.findUnique({
              where: { id: event.campaignId },
            });
            if (!campaign) throw new Error('CAMPAIGN_NOT_FOUND');
            const transaction = await tx.paymentTransaction.findUnique({
              where: { id: event.transactionId },
            });
            if (
              !transaction ||
              transaction.restaurantId !== campaign.restaurantId
            ) {
              throw new Error('PAYMENT_REFERENCE_MISMATCH');
            }
            if (
              Number(transaction.amount) !== Number(campaign.budget) ||
              transaction.currency !== campaign.currency
            ) {
              throw new Error('PAYMENT_AMOUNT_MISMATCH');
            }
            const paid = event.type === 'CAMPAIGN_PAID';
            const updatedTransaction = await tx.paymentTransaction.update({
              where: { id: transaction.id },
              data: {
                status: paid ? 'PAID' : 'REFUNDED',
                provider: event.provider,
                externalPaymentId: event.externalPaymentId,
                paidAt: paid ? transaction.paidAt ?? new Date() : transaction.paidAt,
              },
            });
            const updatedCampaign = await tx.monetizationCampaign.update({
              where: { id: campaign.id },
              data: { status: campaignStatus },
            });
            return {
              transaction: updatedTransaction,
              campaign: updatedCampaign,
            };
          });
          return { accepted: true, ...result };
        }

        const subscriptionStatus = subscriptionStatusForConfirmation(event.type);
        if (subscriptionStatus && 'restaurantId' in event) {
          const subscription = await prisma.restaurantSubscription.findUnique({
            where: { restaurantId: event.restaurantId },
          });
          if (!subscription) {
            return reply.code(404).send({ error: 'SUBSCRIPTION_NOT_FOUND' });
          }
          return {
            accepted: true,
            subscription: await prisma.restaurantSubscription.update({
              where: { restaurantId: event.restaurantId },
              data: {
                status: subscriptionStatus,
                provider: event.provider,
                externalSubscriptionId:
                  event.externalSubscriptionId ??
                  subscription.externalSubscriptionId,
                currentPeriodStart:
                  event.currentPeriodStart ?? subscription.currentPeriodStart,
                currentPeriodEnd:
                  event.currentPeriodEnd ?? subscription.currentPeriodEnd,
              },
            }),
          };
        }
        return reply.code(400).send({ error: 'UNSUPPORTED_PAYMENT_EVENT' });
      } catch (error) {
        if (!(error instanceof Error)) throw error;
        if (error.message === 'CAMPAIGN_NOT_FOUND') {
          return reply.code(404).send({ error: error.message });
        }
        if (
          error.message === 'PAYMENT_REFERENCE_MISMATCH' ||
          error.message === 'PAYMENT_AMOUNT_MISMATCH'
        ) {
          return reply.code(409).send({ error: error.message });
        }
        throw error;
      }
    },
  );

  app.post('/v1/monetization/actions', async (request, reply) => {
    try {
      const actorUserId = userIdFromRequest(request);
      const parsed = actionSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({
          error: 'INVALID_INPUT',
          details: parsed.error.flatten(),
        });
      }
      const body = parsed.data;
      if (!canBillAction(body.action)) {
        return reply.code(400).send({ error: 'NON_BILLABLE_ACTION' });
      }

      const result = await prisma.$transaction(async (tx) => {
        const existingByKey = await tx.billableAction.findUnique({
          where: { idempotencyKey: body.idempotencyKey },
        });
        if (existingByKey) {
          return {
            action: existingByKey,
            duplicate: true,
            charged: existingByKey.billedAt !== null,
          };
        }

        const log = body.recommendationLogId
          ? await tx.recommendationLog.findFirst({
              where: { id: body.recommendationLogId, userId: actorUserId },
            })
          : await tx.recommendationLog.findFirst({
              where: {
                sessionId: body.sessionId,
                userId: actorUserId,
                restaurantId: body.restaurantId,
                ...(body.mealId ? { mealId: body.mealId } : {}),
              },
              orderBy: { rank: 'asc' },
            });
        if (!log) throw new Error('ACTION_NOT_OWNED');

        const existingAction = await tx.billableAction.findFirst({
          where: { recommendationLogId: log.id, action: body.action },
        });
        if (existingAction) {
          return {
            action: existingAction,
            duplicate: true,
            charged: existingAction.billedAt !== null,
          };
        }

        const now = new Date();
        const smartCampaignId = smartCampaignIdFromReasons(log.reasonCodes);
        const campaigns = await tx.monetizationCampaign.findMany({
          where: {
            restaurantId: log.restaurantId,
            status: 'ACTIVE',
            startsAt: { lte: now },
            endsAt: { gte: now },
            remainingBudget: { gt: 0 },
            ...(smartCampaignId
              ? { id: smartCampaignId, channel: 'SMART_CAMPAIGN' }
              : { channel: 'PER_ACTION' }),
          },
        });
        const decision = selectChargeCampaign(campaigns, body.action, now);

        let charged = false;
        if (decision) {
          const update = await tx.monetizationCampaign.updateMany({
            where: {
              id: decision.campaignId,
              status: 'ACTIVE',
              remainingBudget: { gte: decision.amount },
            },
            data: { remainingBudget: { decrement: decision.amount } },
          });
          charged = update.count === 1;
        }

        try {
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
        } catch (error) {
          if (
            error instanceof Prisma.PrismaClientKnownRequestError &&
            error.code === 'P2002'
          ) {
            const duplicate = await tx.billableAction.findFirst({
              where: { recommendationLogId: log.id, action: body.action },
            });
            if (duplicate) {
              return {
                action: duplicate,
                duplicate: true,
                charged: duplicate.billedAt !== null,
              };
            }
          }
          throw error;
        }
      });

      return reply.code(result.duplicate ? 200 : 201).send(result);
    } catch (error) {
      if (error instanceof Error && error.message === 'ACTION_NOT_OWNED') {
        return reply.code(403).send({ error: 'ACTION_NOT_OWNED' });
      }
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.get(
    '/v1/owner/monetization/roi/:restaurantId',
    async (request, reply) => {
      try {
        const userId = userIdFromRequest(request);
        const restaurantId = (request.params as { restaurantId: string })
          .restaurantId;
        await assertOwner(userId, restaurantId);
        const [campaigns, verifiedActions, chargedActions, ledger] =
          await Promise.all([
            prisma.monetizationCampaign.findMany({
              where: { restaurantId },
            }),
            prisma.billableAction.count({
              where: { restaurantId, verified: true },
            }),
            prisma.billableAction.count({
              where: { restaurantId, billedAt: { not: null } },
            }),
            prisma.billingLedger.aggregate({
              where: { restaurantId },
              _sum: { amount: true },
            }),
          ]);
        return {
          campaigns,
          verifiedActions,
          chargedActions,
          totalCharged: ledger._sum.amount ?? 0,
        };
      } catch (error) {
        if (error instanceof Error && error.message === 'FORBIDDEN') {
          return reply.code(403).send({ error: 'FORBIDDEN' });
        }
        return reply.code(401).send({ error: 'AUTH_REQUIRED' });
      }
    },
  );
}
