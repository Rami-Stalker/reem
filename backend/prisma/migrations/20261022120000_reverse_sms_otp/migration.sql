-- Reverse-SMS one-time codes (SYROTP).
--
-- Until now every challenge travelled one way: the platform minted six digits
-- and a transport carried them to the handset. The gap between "the aggregator
-- accepted it" and "it arrived" is the dominant Syrian delivery failure, and no
-- transport in `otp_transport_routes` can close it, because the failure is
-- downstream of all of them.
--
-- A reverse challenge turns the arrow round. The provider mints the code, she
-- sends it from her own handset to a receiver number the platform owns, and the
-- inbound sender check is the proof. These columns are how a challenge row
-- remembers which direction it is facing and which provider ceremony settles
-- it.

CREATE TYPE "OtpDeliveryMode" AS ENUM ('CODE_TO_HANDSET', 'REVERSE_SMS');
CREATE TYPE "ReverseCeremony" AS ENUM ('BINDING', 'VERIFICATION');

-- Existing rows are all classic challenges, which is what the default says.
ALTER TABLE "otp_requests"
  ADD COLUMN "delivery_mode" "OtpDeliveryMode" NOT NULL DEFAULT 'CODE_TO_HANDSET',
  ADD COLUMN "reverse_ceremony" "ReverseCeremony",
  ADD COLUMN "reverse_ref" TEXT,
  ADD COLUMN "reverse_send_to" TEXT;

-- One provider ceremony settles at most one challenge. Without this a replayed
-- start response could be pointed at a second row and verify it for free.
CREATE UNIQUE INDEX "otp_requests_reverse_ref_key"
  ON "otp_requests"("reverse_ref");

-- A reverse row is only coherent with a ceremony and a provider reference, and
-- a classic row must not carry either: the verify path branches on
-- `delivery_mode`, so a row that lies about its mode is a row that takes the
-- wrong branch.
ALTER TABLE "otp_requests"
  ADD CONSTRAINT "otp_requests_reverse_shape" CHECK (
    ("delivery_mode" = 'REVERSE_SMS'
       AND "reverse_ceremony" IS NOT NULL
       AND "reverse_ref" IS NOT NULL)
    OR
    ("delivery_mode" = 'CODE_TO_HANDSET'
       AND "reverse_ceremony" IS NULL
       AND "reverse_ref" IS NULL)
  );
