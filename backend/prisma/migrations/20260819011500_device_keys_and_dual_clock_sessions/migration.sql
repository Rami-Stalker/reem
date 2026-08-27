-- CreateEnum
CREATE TYPE "DeviceKeyStorage" AS ENUM ('SOFTWARE', 'HARDWARE', 'BROWSER_NONEXTRACTABLE');

-- AlterTable
ALTER TABLE "devices" ADD COLUMN     "device_key_id" UUID;

-- AlterTable
ALTER TABLE "guest_sessions" ADD COLUMN     "device_key_id" UUID;

-- AlterTable
ALTER TABLE "refresh_tokens" DROP COLUMN "replaced_by_token_id",
ADD COLUMN     "device_key_id" UUID,
ADD COLUMN     "key_id" TEXT,
ADD COLUMN     "prev_token_id" UUID;

-- AlterTable
ALTER TABLE "sessions" DROP COLUMN "current_refresh_token_hash",
DROP COLUMN "expires_at",
ADD COLUMN     "absolute_expires_at" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "device_key_id" UUID,
ADD COLUMN     "idle_expires_at" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "revoked_reason" TEXT;

-- CreateTable
CREATE TABLE "device_keys" (
    "id" UUID NOT NULL,
    "user_id" UUID,
    "public_key" TEXT NOT NULL,
    "key_storage" "DeviceKeyStorage" NOT NULL DEFAULT 'SOFTWARE',
    "hardware_backed" BOOLEAN NOT NULL DEFAULT false,
    "trust_level" "DeviceTrustLevel" NOT NULL DEFAULT 'UNVERIFIED',
    "label" TEXT,
    "platform" TEXT,
    "os_version" TEXT,
    "model" TEXT,
    "app_version" TEXT,
    "first_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "verified_at" TIMESTAMP(3),
    "revoked_at" TIMESTAMP(3),
    "revoked_reason" TEXT,

    CONSTRAINT "device_keys_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "device_proof_jtis" (
    "id" UUID NOT NULL,
    "device_key_id" UUID NOT NULL,
    "jti" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_proof_jtis_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "device_keys_public_key_key" ON "device_keys"("public_key");

-- CreateIndex
CREATE INDEX "device_keys_user_id_revoked_at_idx" ON "device_keys"("user_id", "revoked_at");

-- CreateIndex
CREATE INDEX "device_keys_last_seen_at_idx" ON "device_keys"("last_seen_at");

-- CreateIndex
CREATE INDEX "device_proof_jtis_expires_at_idx" ON "device_proof_jtis"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "device_proof_jtis_device_key_id_jti_key" ON "device_proof_jtis"("device_key_id", "jti");

-- CreateIndex
CREATE UNIQUE INDEX "devices_device_key_id_key" ON "devices"("device_key_id");

-- CreateIndex
CREATE INDEX "refresh_tokens_device_key_id_idx" ON "refresh_tokens"("device_key_id");

-- CreateIndex
CREATE INDEX "refresh_tokens_expires_at_idx" ON "refresh_tokens"("expires_at");

-- CreateIndex
CREATE INDEX "sessions_device_key_id_idx" ON "sessions"("device_key_id");

-- CreateIndex
CREATE INDEX "sessions_status_idle_expires_at_idx" ON "sessions"("status", "idle_expires_at");

-- CreateIndex
CREATE INDEX "sessions_status_absolute_expires_at_idx" ON "sessions"("status", "absolute_expires_at");

-- AddForeignKey
ALTER TABLE "guest_sessions" ADD CONSTRAINT "guest_sessions_device_key_id_fkey" FOREIGN KEY ("device_key_id") REFERENCES "device_keys"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_device_key_id_fkey" FOREIGN KEY ("device_key_id") REFERENCES "device_keys"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_device_key_id_fkey" FOREIGN KEY ("device_key_id") REFERENCES "device_keys"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "devices" ADD CONSTRAINT "devices_device_key_id_fkey" FOREIGN KEY ("device_key_id") REFERENCES "device_keys"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "device_keys" ADD CONSTRAINT "device_keys_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "device_proof_jtis" ADD CONSTRAINT "device_proof_jtis_device_key_id_fkey" FOREIGN KEY ("device_key_id") REFERENCES "device_keys"("id") ON DELETE CASCADE ON UPDATE CASCADE;

