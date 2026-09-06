-- CreateEnum
CREATE TYPE "CodRiskTier" AS ENUM ('TRUSTED', 'LOW', 'MEDIUM', 'HIGH');

-- CreateEnum
CREATE TYPE "CodAssurance" AS ENUM ('NONE', 'ORDER_CONFIRMATION', 'PREPAYMENT');

-- CreateEnum
CREATE TYPE "CodAssuranceState" AS ENUM ('NOT_REQUIRED', 'PENDING', 'SATISFIED', 'ABANDONED');

-- AlterEnum
ALTER TYPE "OtpPurpose" ADD VALUE 'ORDER_CONFIRMATION';

-- AlterTable
-- Pre-existing drift, not part of this feature: the column carries a database
-- default the schema never declared. Prisma folds it into the next migration
-- to run, and this happens to be it.
ALTER TABLE "addresses" ALTER COLUMN "updated_at" DROP DEFAULT;

-- CreateTable
CREATE TABLE "cod_risk_assessments" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "user_id" UUID,
    "score" DECIMAL(5,2) NOT NULL,
    "confidence" DECIMAL(4,2) NOT NULL,
    "tier" "CodRiskTier" NOT NULL,
    "assurance" "CodAssurance" NOT NULL,
    "state" "CodAssuranceState" NOT NULL DEFAULT 'NOT_REQUIRED',
    "factors" JSONB NOT NULL,
    "rule_codes" TEXT[],
    "exposure_usd" DECIMAL(18,4) NOT NULL,
    "otp_request_id" UUID,
    "satisfied_at" TIMESTAMP(3),
    "expires_at" TIMESTAMP(3),
    "observed_outcome" TEXT,
    "observed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "cod_risk_assessments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "cod_risk_assessments_order_id_key" ON "cod_risk_assessments"("order_id");

-- CreateIndex
CREATE INDEX "cod_risk_assessments_tier_created_at_idx" ON "cod_risk_assessments"("tier", "created_at");

-- CreateIndex
CREATE INDEX "cod_risk_assessments_state_expires_at_idx" ON "cod_risk_assessments"("state", "expires_at");

-- CreateIndex
CREATE INDEX "cod_risk_assessments_user_id_created_at_idx" ON "cod_risk_assessments"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "cod_risk_assessments_observed_outcome_created_at_idx" ON "cod_risk_assessments"("observed_outcome", "created_at");

-- AddForeignKey
ALTER TABLE "cod_risk_assessments" ADD CONSTRAINT "cod_risk_assessments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cod_risk_assessments" ADD CONSTRAINT "cod_risk_assessments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
