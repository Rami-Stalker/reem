-- A device token is an address, not a secret. Only its hash was kept, which
-- made every push unsendable — the platform could recognise a handset it had
-- seen before and had no way to write to it.
--
-- Existing rows keep their hash and get an empty token; those devices are
-- unreachable until the app registers again, which it does on next launch.
ALTER TABLE "push_tokens" ADD COLUMN "token" TEXT NOT NULL DEFAULT '';
