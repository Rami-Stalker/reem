-- AlterTable
ALTER TABLE "users" ADD COLUMN     "totp_required" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "totp_credentials" (
    "user_id" UUID NOT NULL,
    "secret_enc" TEXT NOT NULL,
    "confirmed_at" TIMESTAMP(3),
    "last_used_counter" BIGINT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "totp_credentials_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "recovery_codes" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "code_hash" TEXT NOT NULL,
    "generation" INTEGER NOT NULL DEFAULT 1,
    "used_at" TIMESTAMP(3),
    "used_from_device_key_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recovery_codes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "recovery_codes_user_id_generation_used_at_idx" ON "recovery_codes"("user_id", "generation", "used_at");

-- AddForeignKey
ALTER TABLE "totp_credentials" ADD CONSTRAINT "totp_credentials_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recovery_codes" ADD CONSTRAINT "recovery_codes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

