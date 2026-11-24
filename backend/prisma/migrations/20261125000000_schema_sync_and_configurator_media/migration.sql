-- Idempotent migration bringing migration history in sync with schema.prisma
-- Covers Role enum expansion, Branch.wing, CompanySettings branding URLs,
-- RolePermission table, Vehicle & VehicleColour configurator media/CC columns,
-- and Accessory standard/optional classification & thumbnail columns.

-- 1. Role enum additions
ALTER TYPE "Role" ADD VALUE IF NOT EXISTS 'OWNER';
ALTER TYPE "Role" ADD VALUE IF NOT EXISTS 'ACCOUNTS';
ALTER TYPE "Role" ADD VALUE IF NOT EXISTS 'TELE_CALLER';

-- 2. Branch wing column
ALTER TABLE "Branch"
  ADD COLUMN IF NOT EXISTS "wing" TEXT NOT NULL DEFAULT 'RedWing';

-- 3. Vehicle brochure, CC displacement & configurator media columns
ALTER TABLE "Vehicle"
  ADD COLUMN IF NOT EXISTS "brochureUrl" TEXT,
  ADD COLUMN IF NOT EXISTS "listingImageUrl" TEXT,
  ADD COLUMN IF NOT EXISTS "detailImageUrl" TEXT,
  ADD COLUMN IF NOT EXISTS "ccDisplacement" INTEGER;

-- 4. VehicleColour per-colour showcase image column
ALTER TABLE "VehicleColour"
  ADD COLUMN IF NOT EXISTS "colourImageUrl" TEXT;

-- 5. Accessory standard/optional classification, thumbnail & sortOrder columns
ALTER TABLE "Accessory"
  ADD COLUMN IF NOT EXISTS "isStandard" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "imageUrl" TEXT,
  ADD COLUMN IF NOT EXISTS "sortOrder" INTEGER NOT NULL DEFAULT 0;

-- 6. CompanySettings branding URLs
ALTER TABLE "CompanySettings"
  ADD COLUMN IF NOT EXISTS "logoUrl" TEXT,
  ADD COLUMN IF NOT EXISTS "upiQrUrl" TEXT;

-- 7. RolePermission matrix table
CREATE TABLE IF NOT EXISTS "RolePermission" (
  "id" TEXT NOT NULL,
  "role" TEXT NOT NULL,
  "permissions" JSONB NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "RolePermission_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "RolePermission_role_key" ON "RolePermission"("role");
