export const BILLABLE_ACTIONS = ['RESTAURANT_OPENED', 'NAVIGATION_STARTED', 'ORDER_CLICKED'] as const;
export type BillableAction = typeof BILLABLE_ACTIONS[number];

export const ISO_CURRENCIES = ['USD', 'EUR', 'GBP', 'TRY', 'AED', 'SAR', 'JPY', 'CAD', 'AUD'] as const;

export type RevenueChannel = 'BOOST' | 'PER_ACTION' | 'PRO_SUBSCRIPTION' | 'SMART_CAMPAIGN';

export const minorUnits = (amount: number, currency: string): bigint => {
  const zeroDecimal = new Set(['JPY', 'KRW']);
  const factor = zeroDecimal.has(currency.toUpperCase()) ? 1 : 100;
  return BigInt(Math.round(amount * factor));
};

export const sponsoredDisclosure = (locale = 'en'): string => {
  const labels: Record<string, string> = {
    tr: 'Sponsorlu', en: 'Sponsored', de: 'Gesponsert', fr: 'Sponsorisé', es: 'Patrocinado', ar: 'إعلان ممول',
  };
  return labels[locale] ?? labels.en;
};

export const canBillAction = (action: string): action is BillableAction =>
  BILLABLE_ACTIONS.includes(action as BillableAction);

export const normalizeCountry = (value: string): string => value.trim().toUpperCase().slice(0, 2);
export const normalizeCurrency = (value: string): string => value.trim().toUpperCase().slice(0, 3);
