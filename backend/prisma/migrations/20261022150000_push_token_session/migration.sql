-- A push is a message to a signed-in person, so each address is now tied to
-- the sign-in that registered it. Revoking that session (sign-out, "sign out
-- other devices", removing a device, an admin cutting sessions, expiry) stops
-- the pushes; deleting the session deletes the address.
--
-- Existing rows get NULL and keep working until the app re-registers, which it
-- does on every launch.
ALTER TABLE "push_tokens" ADD COLUMN "session_id" UUID;

CREATE INDEX "push_tokens_session_id_idx" ON "push_tokens"("session_id");

ALTER TABLE "push_tokens"
  ADD CONSTRAINT "push_tokens_session_id_fkey"
  FOREIGN KEY ("session_id") REFERENCES "sessions"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
