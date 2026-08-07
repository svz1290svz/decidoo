export const BILLABLE_ACTIONS = [
  'RESTAURANT_OPENED',
  'NAVIGATION_STARTED',
  'ORDER_CLICKED',
] as const;
export type BillableAction = (typeof BILLABLE_ACTIONS)[number];

export type RevenueChannel =
  | 'BOOST'
  | 'PER_ACTION'
  | 'PRO_SUBSCRIPTION'
  | 'SMART_CAMPAIGN';

const ZERO_DECIMAL_CURRENCIES = new Set([
  'BIF',
  'CLP',
  'DJF',
  'GNF',
  'JPY',
  'KMF',
  'KRW',
  'PYG',
  'RWF',
  'UGX',
  'VND',
  'VUV',
  'XAF',
  'XOF',
  'XPF',
]);

const THREE_DECIMAL_CURRENCIES = new Set([
  'BHD',
  'IQD',
  'JOD',
  'KWD',
  'LYD',
  'OMR',
  'TND',
]);

export const currencyExponent = (currency: string): number => {
  const code = normalizeCurrency(currency);
  if (ZERO_DECIMAL_CURRENCIES.has(code)) return 0;
  if (THREE_DECIMAL_CURRENCIES.has(code)) return 3;
  return 2;
};

export const minorUnits = (
  amount: number,
  currency: string,
  exponent = currencyExponent(currency),
): bigint => {
  if (!Number.isFinite(amount) || amount < 0) {
    throw new RangeError('Amount must be a finite non-negative number.');
  }
  if (!Number.isInteger(exponent) || exponent < 0 || exponent > 6) {
    throw new RangeError('Currency exponent is invalid.');
  }
  return BigInt(Math.round(amount * 10 ** exponent));
};

export const sponsoredDisclosure = (locale = 'en'): string => {
  const labels: Record<string, string> = {
    tr: 'Sponsorlu',
    en: 'Sponsored',
    de: 'Gesponsert',
    fr: 'Sponsorisé',
    es: 'Patrocinado',
    ar: 'إعلان ممول',
  };
  return labels[locale] ?? labels.en ?? 'Sponsored';
};

export const canBillAction = (action: string): action is BillableAction =>
  BILLABLE_ACTIONS.includes(action as BillableAction);

export const normalizeCountry = (value: string): string =>
  value.trim().toUpperCase().slice(0, 2);
export const normalizeCurrency = (value: string): string =>
  value.trim().toUpperCase().slice(0, 3);
