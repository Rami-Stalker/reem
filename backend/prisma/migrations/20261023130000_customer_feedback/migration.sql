-- «ملاحظات ونصائح» and «الشكاوى» — the table `CustomerFeedback` describes.
--
-- The model has been in `schema.prisma` since `8c28731`, but no migration ever
-- created it. `prisma migrate deploy` therefore built a database without the
-- table, `prisma migrate diff` reported drift on every run, and the first
-- route to write a note would have failed on the production database with
-- "relation customer_feedback does not exist". Nothing reads or writes the
-- table yet, so creating it now changes no behaviour.
--
-- Purely additive: two enums, one table, three indexes, two foreign keys to
-- `users`. Both foreign keys are `ON DELETE SET NULL`, as the model says: what
-- she said about the product is still worth reading after she leaves, and it
-- stops being about her the moment she does.
--
-- ## The index rename at the end
--
-- Unrelated to the table, and the only other drift left. In
-- `20260918160000_account_verification` an index was created with a 67-letter
-- name; Postgres keeps only 63 letters, so it cut the name to
-- `…_created_at_i`. Prisma shortens long names differently (`…_created__idx`)
-- and so saw an index it did not know about. Renaming it is metadata only: no
-- rebuild, no lock beyond an instant, and the index keeps working throughout.
-- With it, `prisma migrate diff` against a fresh database reports nothing.

-- CreateEnum
CREATE TYPE "CustomerFeedbackKind" AS ENUM ('SUGGESTION', 'COMPLAINT');

-- CreateEnum
CREATE TYPE "CustomerFeedbackStatus" AS ENUM ('NEW', 'REVIEWING', 'ACTIONED', 'CLOSED');

-- CreateTable
CREATE TABLE "customer_feedback" (
    "id" UUID NOT NULL,
    "user_id" UUID,
    "kind" "CustomerFeedbackKind" NOT NULL,
    "status" "CustomerFeedbackStatus" NOT NULL DEFAULT 'NEW',
    "area" TEXT,
    "subject" TEXT,
    "body" TEXT NOT NULL,
    "context" JSONB,
    "wants_reply" BOOLEAN NOT NULL DEFAULT false,
    "handled_note" TEXT,
    "handled_by_id" UUID,
    "handled_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "customer_feedback_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "customer_feedback_kind_status_created_at_idx" ON "customer_feedback"("kind", "status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "customer_feedback_user_id_created_at_idx" ON "customer_feedback"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "customer_feedback_handled_by_id_idx" ON "customer_feedback"("handled_by_id");

-- AddForeignKey
ALTER TABLE "customer_feedback" ADD CONSTRAINT "customer_feedback_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_feedback" ADD CONSTRAINT "customer_feedback_handled_by_id_fkey" FOREIGN KEY ("handled_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- RenameIndex
ALTER INDEX "account_verification_status_events_verification_id_created_at_i" RENAME TO "account_verification_status_events_verification_id_created__idx";
