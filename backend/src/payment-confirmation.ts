import { timingSafeEqual } from 'node:crypto';

export type PaymentConfirmationType =
  | 'CAMPAIGN_PAID'
  | 'CAMPAIGN_REFUNDED'
  | 'SUBSCRIPTION_ACTIVE'
  | 'SUBSCRIPTION_PAST_DUE'
  | 'SUBSCRIPTION_CANCELLED';

export const secureSecretMatches = (
  provided: string | undefined,
  expected: string | undefined,
): boolean => {
  if (!provided || !expected) return false;
  const left = Buffer.from(provided);
  const right = Buffer.from(expected);
  if (left.length !== right.length) return false;
  return timingSafeEqual(left, right);
};

export const campaignStatusForConfirmation = (
  type: PaymentConfirmationType,
): 'ACTIVE' | 'CANCELLED' | null => {
  if (type === 'CAMPAIGN_PAID') return 'ACTIVE';
  if (type === 'CAMPAIGN_REFUNDED') return 'CANCELLED';
  return null;
};

export const subscriptionStatusForConfirmation = (
  type: PaymentConfirmationType,
): 'ACTIVE' | 'PAST_DUE' | 'CANCELLED' | null => {
  if (type === 'SUBSCRIPTION_ACTIVE') return 'ACTIVE';
  if (type === 'SUBSCRIPTION_PAST_DUE') return 'PAST_DUE';
  if (type === 'SUBSCRIPTION_CANCELLED') return 'CANCELLED';
  return null;
};
