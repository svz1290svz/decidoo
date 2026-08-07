CREATE TYPE "MonetizationChannel" AS ENUM ('BOOST','PER_ACTION','SMART_CAMPAIGN');
CREATE TYPE "CampaignStatus" AS ENUM ('DRAFT','PENDING_PAYMENT','ACTIVE','PAUSED','COMPLETED','CANCELLED');
CREATE TYPE "SubscriptionStatus" AS ENUM ('PENDING','ACTIVE','PAST_DUE','CANCELLED','EXPIRED');
CREATE TYPE "LedgerEntryType" AS ENUM ('CHARGE','CREDIT','REFUND','ADJUSTMENT');

CREATE TABLE "MonetizationCampaign" (
  "id" TEXT PRIMARY KEY,
  "restaurantId" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "channel" "MonetizationChannel" NOT NULL,
  "status" "CampaignStatus" NOT NULL DEFAULT 'DRAFT',
  "budget" DECIMAL(14,2) NOT NULL,
  "remainingBudget" DECIMAL(14,2) NOT NULL,
  "currency" TEXT NOT NULL,
  "countryCode" TEXT NOT NULL,
  "startsAt" TIMESTAMP(3) NOT NULL,
  "endsAt" TIMESTAMP(3) NOT NULL,
  "targetRadiusKm" DECIMAL(6,2),
  "targetMealTypes" TEXT[] NOT NULL,
  "targetCuisines" TEXT[] NOT NULL,
  "bidPerAction" DECIMAL(12,4),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "MonetizationCampaign_restaurantId_fkey" FOREIGN KEY ("restaurantId") REFERENCES "Restaurant"("id") ON DELETE CASCADE
);
CREATE INDEX "MonetizationCampaign_restaurantId_status_idx" ON "MonetizationCampaign"("restaurantId","status");
CREATE INDEX "MonetizationCampaign_status_startsAt_endsAt_idx" ON "MonetizationCampaign"("status","startsAt","endsAt");

CREATE TABLE "RestaurantSubscription" (
  "id" TEXT PRIMARY KEY,
  "restaurantId" TEXT NOT NULL UNIQUE,
  "planCode" TEXT NOT NULL,
  "status" "SubscriptionStatus" NOT NULL DEFAULT 'PENDING',
  "currency" TEXT NOT NULL,
  "countryCode" TEXT NOT NULL,
  "provider" TEXT,
  "externalSubscriptionId" TEXT UNIQUE,
  "currentPeriodStart" TIMESTAMP(3),
  "currentPeriodEnd" TIMESTAMP(3),
  "cancelAtPeriodEnd" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "RestaurantSubscription_restaurantId_fkey" FOREIGN KEY ("restaurantId") REFERENCES "Restaurant"("id") ON DELETE CASCADE
);

CREATE TABLE "BillableAction" (
  "id" TEXT PRIMARY KEY,
  "restaurantId" TEXT NOT NULL,
  "recommendationLogId" TEXT NOT NULL,
  "action" "RecommendationAction" NOT NULL,
  "idempotencyKey" TEXT NOT NULL UNIQUE,
  "verified" BOOLEAN NOT NULL DEFAULT false,
  "amount" DECIMAL(12,4),
  "currency" TEXT,
  "billedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BillableAction_restaurantId_fkey" FOREIGN KEY ("restaurantId") REFERENCES "Restaurant"("id") ON DELETE CASCADE,
  CONSTRAINT "BillableAction_recommendationLogId_fkey" FOREIGN KEY ("recommendationLogId") REFERENCES "RecommendationLog"("id") ON DELETE CASCADE
);
CREATE INDEX "BillableAction_restaurantId_createdAt_idx" ON "BillableAction"("restaurantId","createdAt");

CREATE TABLE "BillingLedger" (
  "id" TEXT PRIMARY KEY,
  "restaurantId" TEXT NOT NULL,
  "campaignId" TEXT,
  "entryType" "LedgerEntryType" NOT NULL,
  "amount" DECIMAL(14,4) NOT NULL,
  "currency" TEXT NOT NULL,
  "referenceType" TEXT NOT NULL,
  "referenceId" TEXT NOT NULL,
  "idempotencyKey" TEXT NOT NULL UNIQUE,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BillingLedger_restaurantId_fkey" FOREIGN KEY ("restaurantId") REFERENCES "Restaurant"("id") ON DELETE CASCADE,
  CONSTRAINT "BillingLedger_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "MonetizationCampaign"("id") ON DELETE SET NULL
);
CREATE INDEX "BillingLedger_restaurantId_createdAt_idx" ON "BillingLedger"("restaurantId","createdAt");
