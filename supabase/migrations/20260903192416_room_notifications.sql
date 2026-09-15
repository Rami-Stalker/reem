-- GENERATED from backend/prisma/migrations/20260903192416_room_notifications/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 732f37dd83d4a35c75a73be10ec33685c1013d8e1c17f8560145361ef7b78264

SET search_path = public, extensions;


-- Reem Rooms — telling the room.
--
-- One enum value and one preference column. Room activity is coalesced per room
-- rather than emitted per gesture (see `RoomNotifier`), so this adds no table:
-- a room's afternoon of votes is one notification row that keeps being rewritten
-- while it stays unread.
--
-- The preference defaults to true. Being invited into a room is asking to be
-- told what happens in it, and a room nobody hears about stops being a
-- conversation.

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'room';

-- AlterTable
ALTER TABLE "notification_preferences" ADD COLUMN     "in_app_rooms" BOOLEAN NOT NULL DEFAULT true;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '732f37dd83d4a35c75a73be10ec33685c1013d8e1c17f8560145361ef7b78264', now(), '20260903192416_room_notifications', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260903192416_room_notifications');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
