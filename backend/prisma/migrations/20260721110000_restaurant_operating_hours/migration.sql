CREATE TABLE IF NOT EXISTS "RestaurantOperatingHour" (
  "id" TEXT NOT NULL,
  "restaurantId" TEXT NOT NULL,
  "dayOfWeek" INTEGER NOT NULL,
  "opensAt" TEXT,
  "closesAt" TEXT,
  "isClosed" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "RestaurantOperatingHour_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "RestaurantOperatingHour_restaurantId_fkey"
    FOREIGN KEY ("restaurantId") REFERENCES "Restaurant"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "RestaurantOperatingHour_dayOfWeek_check"
    CHECK ("dayOfWeek" BETWEEN 0 AND 6)
);

CREATE UNIQUE INDEX IF NOT EXISTS "RestaurantOperatingHour_restaurantId_dayOfWeek_key"
  ON "RestaurantOperatingHour"("restaurantId", "dayOfWeek");
CREATE INDEX IF NOT EXISTS "RestaurantOperatingHour_restaurantId_dayOfWeek_idx"
  ON "RestaurantOperatingHour"("restaurantId", "dayOfWeek");
