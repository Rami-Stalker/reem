# Scheduled jobs

Every job the platform runs on a clock: what it does, whether production needs
it, how it runs, and the decisions taken about each. Audited 2026-09-15.

## How they run

```
NestJS process (always on)
  JobRunner ── discovers every @ScheduledJob
     │  on each tick (UTC)
     ├─ take lease in scheduled_job_states ── held by another instance? → skip
     ├─ run the job, renewing the lease every third of its length
     └─ record SUCCEEDED / FAILED, duration, error; release the lease
```

- **One run per tick, however many instances.** The lease is a row taken with
  one atomic `INSERT … ON CONFLICT … WHERE locked_until < now()`, evaluated on
  the database clock. Verified: ten concurrent claimants → exactly one
  (`job-lease.integration.spec.ts`); two API instances scheduling the same
  jobs against Supabase for six minutes → each minute job ran once a minute,
  not twice.
- **A row, not an advisory lock.** The API reaches Supabase through the
  transaction pooler, where a session advisory lock lives on whichever server
  connection the pooler lent out.
- **Crash-safe.** A dead instance stops renewing; its lease runs out (default
  120 s) and the next tick anywhere takes the job.
- **Catch-up.** Every job with a staleness window (`staleAfterMinutes`) that is
  overdue runs once, 15 s after start-up, shortest window first (sign-in codes
  and stock holds before nightly reconciliation) — so a restart, a deploy or a
  sleeping instance does not postpone escrow release by a day. `catchUp: false`
  opts a job out.
- **Health.** `GET /health/jobs` → 503 when a *critical* job is overdue or has
  failed three times running. For an uptime monitor, never for the host's
  deploy health check (that is `/health/ready`).
- **Manual / external trigger.** `POST /internal/jobs/:name/run` with header
  `X-Reem-Job-Secret: $JOBS_TRIGGER_SECRET` (the route is 404 while the secret
  is unset). It takes the same lease, so it can never double a scheduled run.
- **Shutdown.** On SIGTERM: timers stop, running jobs get up to 20 s to
  finish, leases are released.
- `SCHEDULER_ENABLED=false` switches the timers off on an instance.

## Why this design

The API must run 24/7 regardless — the app and the chat sockets need it — so
putting the jobs in the same always-on process adds no new way to fail. What
was actually wrong before was not *where* the jobs ran but that nothing stopped
them running twice (a zero-downtime deploy briefly runs two containers) and
nothing noticed when they stopped.

| Option | Verdict |
| --- | --- |
| **In-process scheduler + database lease** (chosen) | No extra service or cost. Safe with any number of instances. Observable. |
| Supabase `pg_cron` → HTTP → API | Same dependency on the API being up, plus pg_net, a secret in Vault, and HTTP timeouts on long jobs. It is what the retired Edge Function used; its 31 jobs are paused, not deleted. Possible later through the trigger endpoint. |
| External cron (cron-job.org, GitHub Actions) | Same dependency, plus a third party; GitHub's scheduled workflows are routinely delayed by many minutes, which breaks a 30-minute cash-order hold. Possible through the trigger endpoint, not needed. |
| Separate worker process | Worth it only when the heavy analytics jobs are switched on (see §Growth). Same image with `SCHEDULER_ENABLED=true`, API instances `false`; the lease already makes the split safe. |
| Keep-alive pings to a sleeping free instance | Rejected. A sleeping process has no timers and no sockets; pinging it is a workaround, not an architecture. |

## The jobs

Times are UTC. **Critical** = its silence costs money, stock or access, and
`/health/jobs` alerts on it. **Flag** = returns immediately unless its
environment switch is on (all such switches default off).

### Money and stock — production-critical

| Job | When | What it does | Decision |
| --- | --- | --- | --- |
| `OrdersScheduler.expireUnpaidOrders` | every 10 min | Cancels `PENDING_PAYMENT` orders past their deadline (those without a live cash hold) and returns their stock. | Keep · critical. A deadline that frees stock needs a clock. |
| `OrdersScheduler.releaseExpiredReservations` | :05 past every 10 min | Expires stock reservations whose hold lapsed, whatever state the order is in — the net under the sweep above. | Keep · critical. |
| `CodTrustScheduler.releaseExpiredHolds` | every 10 min | Abandons cash-order holds not confirmed within 30 min, cancels the order, returns stock. | Keep · critical. **Merge considered** with `expireUnpaidOrders` (same rhythm, same effect): kept separate because the two own disjoint sets of orders by design, and merging would re-create the race the exclusion prevents. |
| `CommissionsScheduler.releaseEscrow` | 02:30 | Marks sub-orders past their return window as released, making seller earnings payable. Without it no seller is ever paid. | Keep · critical · catch-up. Now records failures instead of only logging them. |
| `ReturnsScheduler.settleReceivedReturns` | hourly | Refunds returns whose goods the seller confirmed received. | Keep · critical · catch-up. Could also run on the "received" event; the sweep stays as the net and preserves the returns-before-escrow ordering. |
| `CustomerRefundsService.settleUndeliveredRefunds` | hourly | Refunds paid parcels that ended without delivery. Cash-only at launch, so usually nothing to do. | Keep · critical · catch-up. |
| `ReconciliationService.nightly` | 03:00 | Checks the ledger: trial balance, cached-balance drift, suspense, negative liabilities. Read-only; logs findings at error level. | Keep · catch-up. |
| `DeliveryDispatchScheduler.retryFailedDispatches` | every 5 min | Re-offers parcels a carrier refused, with backoff, six attempts. | Keep · critical once a carrier is live. |
| `ExchangeRateSyncService.scheduled` | 06:00 | Fetches the USD/SYP rate and publishes it within move and bounds guards. | Keep · catch-up · flag `FX_SYNC_ENABLED` — a pricing decision for the client. |
| `FxRevaluationService.nightly` | 04:00 | Logs the FX exposure. Writes nothing. | Keep for now: harmless, the only daily FX exposure signal. **Removable** once an admin screen shows exposure. |

### Access and security — production-critical

| Job | When | What it does | Decision |
| --- | --- | --- | --- |
| `OtpOutboxCron.drain` | every 10 s (was 5 s) | Sends queued sign-in codes through the transport chain; escalates silent deliveries; reclaims stuck rows. | **Converted to event-driven**: a code is now sent the moment it is created (`otp.enqueued`). The 10-second poll is the safety net for retries and escalation. No lease — `FOR UPDATE SKIP LOCKED` already makes it safe on many instances. |
| `OtpOutboxCron.retireExpired` | every minute | Shreds the sealed plaintext of expired codes. | Keep · critical. **Bug fixed**: it re-selected already-retired challenges for ever ("Retired 4 expired challenges" every minute), and past 200 of them no new code's plaintext was ever shredded. |
| `AuthRetentionCron.advanceClocks` | every 10 min | Expires sessions past their lifetime, lapses phone changes and recovery cases, completes matured recovery hand-overs. | Keep · critical. |
| `AuthRetentionCron.sweep` | 03:00 | Deletes aged auth telemetry by the retention policy (proof jtis, tokens, sessions, challenges, attempts; routine audit rows after 400 days). | Keep · catch-up. |
| `IdempotencySweeper.sweep` | hourly | Clears expired idempotency keys and claims left in flight by a crash. | Keep. |

### Platform hygiene

| Job | When | What it does | Decision |
| --- | --- | --- | --- |
| `MediaSweeperService.sweep` | hourly | Deletes uploads never attached to anything after 24 h — bytes in Storage, then the row. | Keep. |
| `VisualRetentionService.scheduled` | every 10 min | Deletes visual-search photographs past their retention window. | Keep — it is the privacy promise of that feature. |
| `NotificationsService.processScheduled` | every minute | Starts scheduled campaigns and sends deliveries held for quiet hours. Immediate notifications are already event-driven. | Keep. |
| `CommerceContentScheduler.processLifecycle` | every minute | Publishes scheduled posts and stories; expires stories. | Keep. |
| `MarketScheduler.advanceDrops` | every 15 min | Opens and closes seller "drops". | Keep. **Bug fixed**: it was behind the analytics switch (off by default), so a drop a seller scheduled never opened. |
| `ValueScheduler.collect` | every 30 min | Collects evidence for customer standing (the Value programme). | Keep. |
| `ValueScheduler.nightly` | 03:00 | Decay, momentum and daily snapshot; expires stale grants. | Keep · catch-up. |

### Analytics — optional, off by default

| Job | When | Flag | Notes |
| --- | --- | --- | --- |
| `TrendsScheduler.nightly` | 02:15 | `TRENDS_SCHEDULER_ENABLED` | Trend engine pipeline. |
| `TrendsScheduler.sweepAbandonedCarts` | hourly | `TRENDS_SCHEDULER_ENABLED` | Abandoned-cart signal for trends. |
| `GraphScheduler.nightly` | 02:45 | `TRENDS_SCHEDULER_ENABLED` | Commerce graph rebuild. |
| `SellerIntelligenceScheduler.nightly` | 03:10 | `TRENDS_SCHEDULER_ENABLED` | Listing and shop health snapshots. |
| `MarketScheduler.nightly` | 03:25 | `MARKET_SCHEDULER_ENABLED`, else trends | Market economics and bundles. |
| `IntelligenceScheduler.nightly` | 03:10 | `INTELLIGENCE_SCHEDULER_ENABLED` | Rankings, customer and trust sweeps. |
| `IntelligenceScheduler.reminders` | 06:30 | + `REENGAGEMENT_SCHEDULER_ENABLED` | Outbound re-engagement pushes. Leave off until the copy is approved. |
| `ProductIndexerService.scheduled` | hourly | `VISUAL_SEARCH_INDEXER_ENABLED` | Embeds catalogue photographs. CPU-heavy — see §Growth. |
| `SalonsScheduler.remindUpcoming` | every 10 min | — | Reminds a woman of her appointment `SALONS_REMINDER_LEAD_MINUTES` (12h) ahead. Claims its work by setting `reminder_sent_at` first, so two overlapping passes cannot both send. |
| `OccasionsScheduler.remindUpcoming` | :07 hourly | — | «مناسباتي» countdown at 7, 3 and 1 days before, 10:00–21:00 Damascus only. Claims each mark through `last_reminder_stage` before sending, so overlapping passes ring once. See [OCCASIONS.md](OCCASIONS.md). |
| `SalonsScheduler.closeStale` | every 30 min | — | Auto-completes confirmed appointments 24h past their end and cancels pending ones nobody confirmed. Auto-completion is what eventually makes `can_review` true — without it a review would depend on the owner pressing a button. |

**Merge considered:** the five analytics nightlies form one pipeline ordered by
time offsets (trends → graph → seller intelligence → market → intelligence).
When they are switched on, run them as one orchestrated job instead of trusting
the offsets; not done now because all are off.

### Obsolete

| Job | Decision |
| --- | --- |
| `reem.ValueScheduler.collect.continue` (pg_cron only) | Existed only for the Edge Function's 2-second CPU limit (slices of `collect`). Meaningless on a server. Paused with the other pg_cron jobs; safe to delete from `cron.job`. |

All 31 `reem.*` pg_cron jobs in Supabase are **paused**, not deleted — they call
the retired Edge Function. Delete them once the hosted API has run for a while:

```sql
select cron.unschedule(jobid) from cron.job where jobname like 'reem.%';
```

## On a host that sleeps (Render Free)

A free instance stops after 15 minutes with no request and starts again, in
about a minute, on the next one. Nothing is kept awake artificially; the jobs
are built to be correct anyway:

| Situation | What happens |
| --- | --- |
| Asleep | No job runs. Nothing is lost: every job is a sweep of *what is due now*, read from the database, not a queue in memory. |
| A request wakes it | 15 s after start, every overdue job runs once, shortest window first, each under its lease. A job that has **never** succeeded counts as overdue for catch-up — otherwise a nightly job on an instance always asleep at its hour would never run. Then the normal schedule resumes. Verified: a fresh start caught up 20 jobs in order (sign-in codes and stock holds first, escrow and reconciliation last); a restart right after ran none again. |
| Slept less than a job's window | That job is not overdue; it runs at its next tick (≤ 10 min for the stock and session sweeps). |
| Two containers during a deploy | The lease allows one run per job. |
| Killed mid-run | The lease expires (≤ 120 s) and the next run takes over; the run is recorded as failed. |
| `/health/jobs` just after waking | May answer 503 while the catch-up runs — it is telling the truth: those jobs did not run while the instance slept. |

**What cannot be exact on Free, and what to do about it.** Work that must
happen at a moment *with nobody using the app*:

- a notification campaign scheduled for 18:00, or a seller's drop opening at
  20:00 (`NotificationsService.processScheduled`, `MarketScheduler.advanceDrops`,
  scheduled posts in `CommerceContentScheduler`) — runs when the next person
  opens the app;
- a cash order's 30-minute hold or an unpaid order's deadline — the stock is
  released seconds after the next request, not at the deadline. Nobody can
  buy while the service sleeps, so no sale is lost to it, but the first visitor
  after a long sleep may briefly see an item as held;
- escrow release at 02:30 and the nightly sweeps — run on the first wake after.

Money and access stay correct in every case (deadlines are compared when the
sweep runs, sign-in codes are checked for expiry when used). Only *timing*
moves. When exact timing starts to matter — the first scheduled campaign or
drop — the answer is an always-on instance (`plan: starter` in `render.yaml`,
$7/month), not a ping that keeps the free one awake. An external scheduler
calling `POST /internal/jobs/:name/run` at the exact moments work is due would
also work, but it wakes a free instance as surely as a ping does, and costs
more attention than the $7.

## Growth

- **Heavy jobs on a small instance.** On 0.5 CPU, `ProductIndexerService` and
  the analytics nightlies would compete with requests. When turning them on,
  run a second instance of the same image as a worker
  (`SCHEDULER_ENABLED=true`, and `false` on the API instance). No code change.
- **More API instances.** The scheduler is ready. Chat sockets, the in-memory
  cache and the rate limiter are not — see `docs/DEPLOYMENT.md`.
