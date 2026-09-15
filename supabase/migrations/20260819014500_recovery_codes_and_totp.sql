-- GENERATED from backend/prisma/migrations/20260819014500_recovery_codes_and_totp/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: caeed2d4125aa9ff0aa231cefecc82b152199528dd97c8d94c7cf03e05db9946

SET search_path = public, extensions;


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


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'caeed2d4125aa9ff0aa231cefecc82b152199528dd97c8d94c7cf03e05db9946', now(), '20260819014500_recovery_codes_and_totp', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260819014500_recovery_codes_and_totp');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
