-- ─────────────────────────────────────────────────────────────────────────────
-- Reem on Supabase · jobs that run in slices
--
-- An Edge Function invocation gets 2 s of CPU. The half-hourly value sweep
-- (ValueScheduler.collect) needs more than that in one go, so on Supabase it
-- runs in slices (supabase/edge/src/scheduling/edge-value-collector.service.ts)
-- and keeps its place here between invocations. A row exists only while a run
-- is unfinished; while it does, pg_cron calls the job every minute to carry on.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS reem_supabase.job_progress (
  job        text        PRIMARY KEY,
  state      jsonb       NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE reem_supabase.job_progress ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON reem_supabase.job_progress FROM PUBLIC, anon, authenticated;
GRANT ALL ON reem_supabase.job_progress TO service_role;

-- The continuation: every minute, only while a sweep is unfinished. A run
-- stuck for an hour (its isolate killed mid-slice) is picked up again too —
-- each slice saves after every unit of work, so nothing is repeated but the
-- unit that was interrupted, and recomputing a profile is idempotent.
SELECT cron.schedule(
  'reem.ValueScheduler.collect.continue', '* * * * *',
  $cmd$SELECT reem_supabase.invoke_cron('ValueScheduler.collect') WHERE EXISTS (SELECT 1 FROM reem_supabase.job_progress WHERE job = 'value.collect')$cmd$
);
