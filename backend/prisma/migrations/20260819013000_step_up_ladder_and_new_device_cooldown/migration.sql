-- CreateEnum
CREATE TYPE "AssuranceLevel" AS ENUM ('AAL1', 'AAL2', 'AAL3');

-- CreateEnum
CREATE TYPE "StepUpMethod" AS ENUM ('OTP', 'TOTP', 'RECOVERY_CODE');

-- AlterTable
ALTER TABLE "sessions" ADD COLUMN     "assurance_level" "AssuranceLevel" NOT NULL DEFAULT 'AAL1',
ADD COLUMN     "elevated_until" TIMESTAMP(3),
ADD COLUMN     "new_device_cooldown_until" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "step_up_grants" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "session_id" UUID,
    "scope" TEXT NOT NULL,
    "method" "StepUpMethod" NOT NULL,
    "challenge_id" UUID,
    "issued_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "consumed_at" TIMESTAMP(3),
    "ip_address" TEXT,
    "user_agent" TEXT,

    CONSTRAINT "step_up_grants_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "step_up_grants_user_id_scope_consumed_at_idx" ON "step_up_grants"("user_id", "scope", "consumed_at");

-- CreateIndex
CREATE INDEX "step_up_grants_session_id_expires_at_idx" ON "step_up_grants"("session_id", "expires_at");

-- AddForeignKey
ALTER TABLE "step_up_grants" ADD CONSTRAINT "step_up_grants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "step_up_grants" ADD CONSTRAINT "step_up_grants_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

