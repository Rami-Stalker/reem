-- ─────────────────────────────────────────────────────────────────────────────
-- Reem on Supabase · one invocation per sliced job at a time
--
-- The per-minute continuation and a manual run could otherwise load the same
-- saved position and both advance it. `leased_until` is a short lease taken
-- when a slice starts; an invocation that finds it live leaves at once, and a
-- lease left by an isolate killed mid-slice expires on its own.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE reem_supabase.job_progress ADD COLUMN IF NOT EXISTS leased_until timestamptz;

-- The continuation gate counts an unfinished run only (`state` is JSON null
-- for a row that exists solely to hold a lease).
SELECT cron.schedule(
  'reem.ValueScheduler.collect.continue', '* * * * *',
  $cmd$SELECT reem_supabase.invoke_cron('ValueScheduler.collect') WHERE EXISTS (SELECT 1 FROM reem_supabase.job_progress WHERE job = 'value.collect' AND state <> 'null'::jsonb)$cmd$
);
