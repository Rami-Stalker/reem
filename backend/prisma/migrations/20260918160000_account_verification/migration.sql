-- Real account verification.
--
-- ## What the badge used to mean
--
-- `users.is_verified` was set to `true` by the OTP exchange — `otp.service.ts`
-- wrote `{ isVerified: true, phoneVerifiedAt: now }` together, and so did
-- registration, the phone-change flow and account recovery. Every account that
-- had ever received a text message therefore wore «موثّقة» beside its name,
-- rendered by `serializePublicUser` and drawn on every post card, every review
-- byline and every storefront header — identical to the badge a reviewed
-- boutique wore.
--
-- So the column said "this person received a text message" while the interface
-- said "Reem vouches for this person". That is the defect this migration and
-- the module beside it exist to close.
--
-- ## What it means now
--
--  * `phone_verified_at` — she proved the number. Unchanged, still written by
--    the OTP exchange, and now the *only* thing that exchange writes.
--  * `is_verified` / `verified_at` — a human reviewed evidence and granted the
--    badge. Written in exactly one place, `AccountVerificationService.decide`.
--
-- ## The reset, and what survives it
--
-- Every badge currently on an account was granted by the OTP path, so it is
-- withdrawn — with one exception, and it is a real one: an account with
-- `seller_verified_at` set went through `SellerVerification`, which is a
-- documented application a member of staff approved. That badge was earned and
-- is kept, dated to the day it was granted.
--
-- Nothing else about those accounts changes. `phone_verified_at` is untouched,
-- so no sign-in, no COD assessment and no recovery flow is affected — the two
-- readers that were using `is_verified` to mean "phone verified"
-- (`cod-facts.service.ts` and `auth.service.ts`) are corrected in the same
-- commit to read `phone_verified_at`, which they should always have read.

CREATE TYPE "AccountVerificationStatus" AS ENUM (
  'PENDING',
  'UNDER_REVIEW',
  'NEEDS_MORE_INFO',
  'APPROVED',
  'REJECTED',
  'REVOKED'
);

CREATE TYPE "AccountVerificationKind" AS ENUM ('PERSONAL', 'BUSINESS');

ALTER TABLE "users" ADD COLUMN "verified_at" TIMESTAMP(3);

CREATE TABLE "account_verifications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "kind" "AccountVerificationKind" NOT NULL DEFAULT 'PERSONAL',
    "status" "AccountVerificationStatus" NOT NULL DEFAULT 'PENDING',
    "legal_name" TEXT NOT NULL,
    "document_type" TEXT,
    "document_front_url" TEXT,
    "document_back_url" TEXT,
    "selfie_url" TEXT,
    "supporting_urls" JSONB NOT NULL DEFAULT '[]',
    "note" TEXT,
    "review_note" TEXT,
    "reviewed_by" UUID,
    "reviewed_at" TIMESTAMP(3),
    "submitted_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "account_verifications_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "account_verification_status_events" (
    "id" UUID NOT NULL,
    "verification_id" UUID NOT NULL,
    "status" "AccountVerificationStatus" NOT NULL,
    "reason" TEXT NOT NULL,
    "actor_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "account_verification_status_events_pkey" PRIMARY KEY ("id")
);

-- One live claim per account: re-applying reopens the row rather than filing a
-- second one, which is what keeps the queue answerable.
CREATE UNIQUE INDEX "account_verifications_user_id_key"
    ON "account_verifications" ("user_id");

-- The queue: oldest first within a status.
CREATE INDEX "account_verifications_status_submitted_at_idx"
    ON "account_verifications" ("status", "submitted_at");

CREATE INDEX "account_verification_status_events_verification_id_created_at_idx"
    ON "account_verification_status_events" ("verification_id", "created_at");

CREATE INDEX "account_verification_status_events_actor_id_created_at_idx"
    ON "account_verification_status_events" ("actor_id", "created_at");

ALTER TABLE "account_verifications"
    ADD CONSTRAINT "account_verifications_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users" ("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "account_verification_status_events"
    ADD CONSTRAINT "account_verification_status_events_verification_id_fkey"
    FOREIGN KEY ("verification_id") REFERENCES "account_verifications" ("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "account_verification_status_events"
    ADD CONSTRAINT "account_verification_status_events_actor_id_fkey"
    FOREIGN KEY ("actor_id") REFERENCES "users" ("id")
    ON DELETE SET NULL ON UPDATE CASCADE;

-- ── The reset ──────────────────────────────────────────────────────────────

-- A boutique whose application staff approved keeps its badge, dated to the
-- day that decision was taken.
UPDATE "users"
SET "verified_at" = "seller_verified_at"
WHERE "seller_verified_at" IS NOT NULL
  AND "is_verified" = true;

-- Everyone else's badge came from receiving a text message. It goes.
UPDATE "users"
SET "is_verified" = false
WHERE "is_verified" = true
  AND "seller_verified_at" IS NULL;
