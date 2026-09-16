-- Push that actually reaches a closed app.
--
-- Two things were missing for a push notification to be a real one rather than
-- a row in a table:
--
--   1. A *handset identity*. A push token is reissued by the provider after a
--      reinstall, a restore, or a long idle period, and the old one keeps
--      answering for a while. With only a token hash to dedupe on, one woman
--      reinstalling twice accumulated three rows and got every notification
--      three times. `device_id` retires a handset's previous token.
--
--   2. A *retry clock*. Every delivery got exactly one attempt: a provider
--      answering 503 for ninety seconds lost every order-shipped message sent
--      during it, permanently. `attempts` and `next_attempt_at` are the
--      backoff.
--
-- Additive only. Every column is nullable or defaulted, so rows already in
-- these tables are valid without a backfill.

-- AlterTable
ALTER TABLE "push_tokens"
    ADD COLUMN "device_id" TEXT,
    ADD COLUMN "app_version" TEXT,
    ADD COLUMN "locale" TEXT,
    ADD COLUMN "failure_count" INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN "last_failure_reason" TEXT,
    ADD COLUMN "disabled_at" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "push_tokens_device_id_idx" ON "push_tokens"("device_id");

-- AlterTable
ALTER TABLE "notification_deliveries"
    ADD COLUMN "attempts" INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN "next_attempt_at" TIMESTAMP(3);

-- CreateIndex
--
-- The exact shape of the question the delivery worker asks on every pass:
-- queued rows whose backoff has elapsed.
CREATE INDEX "notification_deliveries_status_next_attempt_at_idx"
    ON "notification_deliveries"("status", "next_attempt_at");
