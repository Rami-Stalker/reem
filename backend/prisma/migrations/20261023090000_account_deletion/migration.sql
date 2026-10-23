-- Self-service account deletion. The row stays, anonymised, because orders,
-- invoices and ledger entries the law requires us to keep point at it; this
-- marks it as deleted rather than merely suspended, so it is never re-enabled.
ALTER TABLE "users" ADD COLUMN "deleted_at" TIMESTAMP(3);
