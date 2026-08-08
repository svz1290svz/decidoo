# Decidoo Global Monetization

Decidoo keeps consumer access free and monetizes restaurants through four independent channels.

## 1. Boost
Restaurants fund time-bounded campaigns. Sponsored placements never bypass relevance eligibility and must be disclosed in the user's locale. Budget, currency, country, targeting window and targeting dimensions are stored per campaign.

## 2. Verified action pricing
Only high-intent actions are billable: restaurant opened, navigation started, and order clicked. Every action requires an idempotency key so retries cannot double-charge. View, like and save signals remain non-billable product-learning signals.

## 3. Decidoo Pro
Restaurant subscriptions are modeled independently from campaigns. Provider identifiers and billing periods are external-provider fields so the core remains payment-provider neutral and can support different processors by country.

## 4. Smart campaigns
Campaigns support radius, meal-type and cuisine targeting, schedules, budget ceilings and optional action bids. The recommendation engine must preserve organic relevance and mark paid placement as sponsored.

## Global rules
- Monetary records always store ISO currency codes; never assume TRY or USD.
- Country and currency are explicit per commercial object.
- Billing ledger entries and billable actions are idempotent.
- Payment-provider webhooks are the authority for paid/subscription state; client callbacks are not.
- Refunds are ledger entries, not destructive edits.
- Taxes, VAT/GST, invoices and merchant-of-record responsibilities belong to the selected provider/country integration layer.
- Production must use integer provider minor units at the payment boundary and Decimal in the accounting database.
- Never charge for an impression alone in the verified-action channel.
- Fraud controls should reject duplicate, bot, impossible-travel and self-generated restaurant traffic before billing.

## External integrations still required
The repository intentionally does not hard-code a payment processor. Before charging real money, connect one or more compliant payment providers, configure webhook signing secrets, tax/invoice rules, refund handling, merchant onboarding and payout/reconciliation policy for each launch market.
