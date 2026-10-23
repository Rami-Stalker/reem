-- «مناسباتي» — the occasions she is getting ready for.
--
-- Purely additive. One new table, one new enum, and one new value on
-- `NotificationType`. Nothing existing changes shape and no row is rewritten.
--
-- ## Why so few columns
--
-- An occasion points at things that already exist rather than copying them:
-- the look is a `closet_looks` row and the salon is an `appointments` row.
-- The checklist ("look chosen", "salon booked", "pieces missing") is derived
-- from those two links at read time, so it cannot drift from them — a booking
-- the salon cancels turns its step back to "to do" without anything here
-- having to be told. Both links are `ON DELETE SET NULL`: deleting a look must
-- not delete the wedding it was meant for.
--
-- `done_steps` holds only what the server cannot observe (the gift), and
-- `last_reminder_stage` is what keeps the countdown sweep idempotent across
-- the catch-up runs a sleeping instance performs on waking.

-- CreateEnum
CREATE TYPE "OccasionKind" AS ENUM ('WEDDING', 'ENGAGEMENT', 'HENNA', 'EID', 'BIRTHDAY', 'GRADUATION', 'EVENING', 'FAMILY_VISIT', 'WORK', 'TRAVEL', 'OTHER');

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'occasion';

-- CreateTable
CREATE TABLE "occasions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "title" VARCHAR(80) NOT NULL,
    "kind" "OccasionKind" NOT NULL DEFAULT 'OTHER',
    "date" DATE NOT NULL,
    "starts_at_time" VARCHAR(5),
    "location" VARCHAR(120),
    "circle" VARCHAR(80),
    "circle_key" VARCHAR(80),
    "note" VARCHAR(500),
    "look_id" UUID,
    "appointment_id" UUID,
    "done_steps" TEXT[],
    "reminders_enabled" BOOLEAN NOT NULL DEFAULT true,
    "last_reminder_stage" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "occasions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "occasions_user_id_date_idx" ON "occasions"("user_id", "date");

-- CreateIndex
CREATE INDEX "occasions_reminders_enabled_date_idx" ON "occasions"("reminders_enabled", "date");

-- CreateIndex
CREATE INDEX "occasions_user_id_circle_key_idx" ON "occasions"("user_id", "circle_key");

-- CreateIndex
CREATE INDEX "occasions_look_id_idx" ON "occasions"("look_id");

-- CreateIndex
CREATE INDEX "occasions_appointment_id_idx" ON "occasions"("appointment_id");

-- AddForeignKey
ALTER TABLE "occasions" ADD CONSTRAINT "occasions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "occasions" ADD CONSTRAINT "occasions_look_id_fkey" FOREIGN KEY ("look_id") REFERENCES "closet_looks"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "occasions" ADD CONSTRAINT "occasions_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "appointments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
