-- GENERATED from backend/prisma/migrations/20260819000757_identity_phone_only_female_attestation/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 7e2682c466283ef1613e617b9f64f18cad5f1ca9d59b9c395de315c132430744

SET search_path = public, extensions;


/*
  Warnings:

  - You are about to drop the `linked_accounts` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "linked_accounts" DROP CONSTRAINT "linked_accounts_user_id_fkey";

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "declared_female_at" TIMESTAMP(3);

-- DropTable
DROP TABLE "linked_accounts";

-- DropEnum
DROP TYPE "AuthProvider";


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '7e2682c466283ef1613e617b9f64f18cad5f1ca9d59b9c395de315c132430744', now(), '20260819000757_identity_phone_only_female_attestation', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260819000757_identity_phone_only_female_attestation');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
