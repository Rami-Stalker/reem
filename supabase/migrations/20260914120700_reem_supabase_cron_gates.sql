-- ─────────────────────────────────────────────────────────────────────────────
-- Reem on Supabase · tighter gates for two minute-by-minute jobs
--
-- Measured on the live project: both jobs were invoked every minute with
-- nothing to do, because their gates matched rows the jobs themselves never
-- clear.
--
--  - CommerceContentScheduler.processLifecycle publishes SCHEDULED content only
--    once moderation has APPROVED it; scheduled content awaiting review kept
--    the gate open.
--  - OtpOutboxCron.retireExpired cancels the outbox row of an expired
--    challenge but leaves the challenge PENDING; the cancelled outbox kept the
--    gate open.
--
-- Same schedule, same job; only the "is there work?" predicate changes.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT cron.schedule(
  'reem.CommerceContentScheduler.processLifecycle', '* * * * *',
  $cmd$SELECT reem_supabase.invoke_cron('CommerceContentScheduler.processLifecycle') WHERE EXISTS (SELECT 1 FROM public.commerce_contents WHERE (status = 'SCHEDULED' AND moderation_status = 'APPROVED' AND scheduled_at <= (now() AT TIME ZONE 'utc')) OR (status = 'PUBLISHED' AND expires_at <= (now() AT TIME ZONE 'utc')))$cmd$
);

SELECT cron.schedule(
  'reem.OtpOutboxCron.retireExpired', '* * * * *',
  $cmd$SELECT reem_supabase.invoke_cron('OtpOutboxCron.retireExpired') WHERE EXISTS (SELECT 1 FROM public.otp_requests r JOIN public.otp_outbox o ON o.challenge_id = r.id WHERE r.status = 'PENDING' AND r.expires_at < (now() AT TIME ZONE 'utc') AND o.status NOT IN ('CANCELLED', 'EXHAUSTED'))$cmd$
);
