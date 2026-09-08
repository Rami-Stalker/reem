-- The unique key on experiment events was not unique.
--
-- `metric` was nullable and null for every exposure, and PostgreSQL treats
-- NULLs as *distinct* in a unique index — so (experiment, subject, EXPOSURE,
-- NULL) matched nothing and three identical rows sat happily side by side. The
-- "one exposure per screen" guarantee the whole measurement rests on was not a
-- guarantee at all: a component that rendered twice doubled its arm's exposure
-- count and halved its conversion rate.
--
-- Exactly the trap `LedgerAccount.ownerKey` was built to avoid, met again.
-- Same answer: a non-null column with a sentinel, where there are no NULLs to
-- be distinct from each other.
UPDATE "experiment_events" SET "metric" = '' WHERE "metric" IS NULL;
ALTER TABLE "experiment_events" ALTER COLUMN "metric" SET DEFAULT '';
ALTER TABLE "experiment_events" ALTER COLUMN "metric" SET NOT NULL;
