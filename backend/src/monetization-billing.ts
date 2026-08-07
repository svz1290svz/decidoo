import type { MonetizationChannel } from '@prisma/client';
import { canBillAction } from './monetization-domain.js';

export type CampaignForBilling = {
  id: string;
  channel: MonetizationChannel;
  status: string;
  startsAt: Date;
  endsAt: Date;
  remainingBudget: unknown;
  bidPerAction: unknown;
  currency: string;
};

export type ChargeDecision = {
  campaignId: string;
  amount: number;
  currency: string;
} | null;

const asNumber = (value: unknown): number => {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') return Number(value);
  if (value && typeof value === 'object' && 'toString' in value) {
    return Number(String(value));
  }
  return Number.NaN;
};

export const selectChargeCampaign = (
  campaigns: CampaignForBilling[],
  action: string,
  now = new Date(),
): ChargeDecision => {
  if (!canBillAction(action)) return null;

  const eligible = campaigns
    .filter((campaign) => campaign.status === 'ACTIVE')
    .filter((campaign) => campaign.startsAt <= now && campaign.endsAt >= now)
    .filter(
      (campaign) =>
        campaign.channel === 'PER_ACTION' || campaign.channel === 'SMART_CAMPAIGN',
    )
    .map((campaign) => ({
      campaign,
      remaining: asNumber(campaign.remainingBudget),
      bid: asNumber(campaign.bidPerAction),
    }))
    .filter(
      (item) =>
        Number.isFinite(item.remaining) &&
        Number.isFinite(item.bid) &&
        item.bid > 0 &&
        item.remaining >= item.bid,
    )
    .sort((a, b) => b.bid - a.bid || a.campaign.id.localeCompare(b.campaign.id));

  const winner = eligible[0];
  if (!winner) return null;
  return {
    campaignId: winner.campaign.id,
    amount: winner.bid,
    currency: winner.campaign.currency,
  };
};
