-- The audit trail can now be asked about a record rather than only about a
-- person.
--
-- `audit_logs` recorded the actor, the action and the time, and put the thing
-- acted upon inside an unindexed JSON blob -- if it recorded it at all. So the
-- question actually asked after an incident, "show me everything that happened
-- to this order", or to this seller, or to this payout, had no answer. Two
-- columns and one index make it a query.

ALTER TABLE "audit_logs" ADD COLUMN IF NOT EXISTS "target_type" TEXT;
ALTER TABLE "audit_logs" ADD COLUMN IF NOT EXISTS "target_id" TEXT;

CREATE INDEX IF NOT EXISTS "audit_logs_target_type_target_id_created_at_idx"
  ON "audit_logs" ("target_type", "target_id", "created_at");
