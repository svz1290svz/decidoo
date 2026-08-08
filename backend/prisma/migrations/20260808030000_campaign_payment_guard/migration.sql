-- Defense-in-depth: prepaid monetization campaigns must never become ACTIVE
-- unless a matching paid funding transaction exists for that exact campaign.
-- PER_ACTION is intentionally postpaid and is therefore exempt.

CREATE OR REPLACE FUNCTION "decidoo_guard_campaign_activation"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW."status" = 'ACTIVE'::"CampaignStatus"
     AND NEW."channel" <> 'PER_ACTION'::"MonetizationChannel"
     AND (OLD."status" IS DISTINCT FROM NEW."status") THEN
    IF NOT EXISTS (
      SELECT 1
      FROM "PaymentTransaction" p
      WHERE p."restaurantId" = NEW."restaurantId"
        AND p."status" = 'PAID'::"PaymentStatus"
        AND p."currency" = NEW."currency"
        AND p."amount" = NEW."budget"
        AND p."metadata"->>'campaignId' = NEW."id"
    ) THEN
      RAISE EXCEPTION 'PAID_CAMPAIGN_FUNDING_REQUIRED'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS "MonetizationCampaign_payment_guard" ON "MonetizationCampaign";

CREATE TRIGGER "MonetizationCampaign_payment_guard"
BEFORE UPDATE OF "status" ON "MonetizationCampaign"
FOR EACH ROW
EXECUTE FUNCTION "decidoo_guard_campaign_activation"();
