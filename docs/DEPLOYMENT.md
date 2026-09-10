# Deployment

## The single-instance constraint

**Run exactly one API process. Do not scale this service horizontally yet.**

This is a deliberate, documented launch decision, not an oversight — the client
chose a single server for the first months and the platform is built to match.
Everything the API needs to share between requests currently lives *inside the
process*, so a second instance does not double capacity, it splits state:

| What is shared in-process | What a second instance does to it |
| --- | --- |
| **29 `@Cron` jobs** (`grep -rn "@Cron(" backend/src --include=*.ts | grep -v spec`) | Every sweep runs twice. Money is safe — ledger postings are idempotent on their `reference`, and the escrow sweep re-reads its own flag — but **notification campaigns, the media sweeper, exchange-rate sync and the trend/graph rebuilds are not idempotent**. The visible failure is a customer receiving the same push twice. |
| **`CacheService`** (`common/cache/cache.service.ts`) — a `Map` per process | Two customers get two different versions of the catalogue, and an invalidation on one instance leaves the other serving stale prices. |
| **`ThrottlerGuard`** — in-memory storage | The rate limit multiplies by the number of instances. The brute-force protection on `/auth/otp/login/verify` is the one that matters. |
| **`ChatRealtimeGateway`** — a hand-rolled WebSocket server with no pub/sub | A message never reaches a woman connected to a different instance. |
| **`LocalDiskDriver`** — uploads on the API host's disk | An image uploaded to instance A is a 404 on instance B. |
| **`EventEmitter2`** — in-process events | Listeners on the other instance never fire. |

### What lifting the constraint requires

The seams are already drawn, so this is additive work rather than a rewrite —
see §13 and phase 3 of [production-gap-analysis.md](production-gap-analysis.md):

1. Redis for the cache, the throttler storage, the chat pub/sub, and a
   distributed lock.
2. A separate `worker` process holding every `@Cron`, elected by that lock, with
   the API processes running none.
3. An `S3Driver` behind the existing `MediaStorageDriver` interface.

Until all three exist, one process.

## The nightly order

The scheduled jobs are sequenced, and the order is load-bearing:

| When | Job | Why here |
| --- | --- | --- |
| hourly | `ReturnsScheduler.settleReceivedReturns` | Returns that came back today take their share out of escrow first. |
| hourly | `CustomerRefundsService.settleUndeliveredRefunds` | Same reason, for parcels that never arrived. |
| every 10 min | `CodTrustScheduler.releaseExpiredHolds` | A cash order held for a confirmation code has a 30-minute clock; a coarser sweep would hold stock past its own deadline. |
| every 10 min | `OrdersScheduler.expireUnpaidOrders` | The backstop beneath it: every *other* way an order can be left unpaid. Skips orders with a live cash hold so the two sweeps never race. |
| every 10 min (offset :05) | `OrdersScheduler.releaseExpiredReservations` | The net beneath *that*: releases stock by expiring the **reservation**, not the order, so a sub-order wedged in a state nothing can move still gives its garments back. Offset five minutes so an order cancelled at :00 has already released its own. Any release here is logged as a warning — it means the order path could not reach it, which is worth looking at. |
| every 5 min | `DeliveryDispatchScheduler.retryFailedDispatches` | Re-offers parcels a carrier refused, with a widening backoff (2, 8, 18, 32, 50 min) and six attempts. The retry endpoint existed and nothing called it, so a dispatch that failed on a thirty-second carrier blip was never collected at all — and the seller's escrow clock runs from delivery, so nothing downstream started either. After six attempts it logs at error level and waits for the delivery desk. |
| hourly | `IdempotencySweeper.sweep` | Clears expired request keys, and — the one that matters — claims left `IN_FLIGHT` by a process that died mid-request. Without it, retrying that request answers `409` until the key expires a day later. |
| **02:30** | `CommissionsScheduler.releaseEscrow` | What is left after the returns is final, and becomes payable. **Without this nothing a seller earns ever becomes payable at all.** |
| 03:00 | `ReconciliationService.nightly` | Checks a settled picture. Running it before the release would report a discrepancy that fixes itself half an hour later. |
| 04:00 | `FxRevaluationService.nightly` | Revalues what remains. |

## Environment

`config/env.validation.ts` refuses to boot in production with any of:

- `CORS_ORIGINS=*` — reflects any origin, and the API pairs that with credentials
- `OTP_DEV_ECHO=true` — returns one-time codes in the response body
- `OTP_DEV_INBOX_ENABLED=true` — serves plaintext codes to anyone who can reach the port
- `PAYMENTS_SANDBOX_CONFIRMATION=true` — lets a customer mark her own order paid
- `MEDIA_PUBLIC_ORIGIN` unset — every stored image URL points at localhost

Set `TRUST_PROXY` behind a reverse proxy, or rate limiting sees the proxy's IP
for every request and the whole platform shares one throttle bucket.

## Payment rails at launch

The platform launches **cash-only**: `COD` and `COURIER_COLLECT`. Every
electronic provider in `payments/providers/` is a sandbox stub that declares
`attestsSettlement = false`, and `PaymentsService.verify` refuses with
`PAYMENT_CONFIRMATION_UNAVAILABLE` for any rail that cannot prove money moved.
That refusal is the safety net: without it, a customer could mark her own order
paid and receive the goods for free. Do not set
`PAYMENTS_SANDBOX_CONFIRMATION` outside a developer's machine.

Wiring a real gateway means implementing `PaymentProvider`, setting
`attestsSettlement` only once `verify` authenticates the gateway's own answer,
and adding a signed webhook — the same shape
`delivery/dispatch/delivery-webhook.controller.ts` already uses.

## Backups

There was no backup procedure before the pre-launch audit. Not a weak one —
none. This platform keeps a double-entry ledger, escrow balances and cash
orders, so the database *is* the business, and an hour of it lost is an hour of
money nobody can account for.

```bash
cd backend && npm run db:backup
```

Writes `backups/reem-<timestamp>.dump` (custom format, compressed, restorable
table by table) plus a `.json` manifest recording the server version, the
migration the schema was at, and exact row counts for the fifteen tables that
carry money. `--out <dir>` chooses where; `--keep <n>` prunes older dumps and
defaults to 14. The manifest is what makes a restore *verifiable*: without it,
"the restore worked" is an opinion.

Two things this does not do, and neither is optional to solve:

**It leaves the dump on the same host.** A dump beside the database survives a
dropped table and nothing else — not a failed disk, not a lost server, not
ransomware. Copying it somewhere else is a deployment step, and until it exists
there is no backup.

**It is not point-in-time recovery.** A nightly dump means up to a day of orders
can be lost. Real PITR is `archive_mode = on` with WAL archiving to a second
machine. That is a server configuration and a second host — a cost decision, so
it is recorded here rather than assumed. **Until it exists, the recovery point
objective is "the last dump", and everyone should know that number.**

## Restores

A backup nobody has restored is a hypothesis. The failure mode is not that
`pg_restore` errors; it is that it succeeds and six tables are empty, which
nobody discovers during an incident and stays calm.

```bash
cd backend && npm run db:restore:verify -- --into postgresql://…/reem_restore_check
```

Restores the newest dump into a scratch database and compares every row count
against the manifest, failing loudly on any difference. **Run it on a schedule**,
not once. Verified on 2026-09-10 against the development dataset: 15/15 tables
matched, 5.3 MB dumped in 3.9s and restored in 10.3s.

To actually recover:

```bash
cd backend && npm run db:restore -- --file backups/reem-….dump --into "$DATABASE_URL"
```

`--into` is required and never defaults. The one mistake the script must be
incapable of is overwriting production because a flag was forgotten, so
`--verify` also refuses a target equal to `DATABASE_URL`.

Both scripts accept Prisma's connection string. libpq rejects `?schema=public`
outright — `invalid URI query parameter: "schema"` — and that parameter is in
`.env.example`, so a script written against `DATABASE_URL` naively fails on
every real deployment. `scripts/pg-url.mjs` strips Prisma's parameters and
carries the schema across as a `search_path`.

Dumps are git-ignored. A dump of this platform is every customer's phone number,
address and order history in one file.

## Health probes

Point them at different endpoints; they answer different questions.

| Probe | Endpoint | Touches |
| --- | --- | --- |
| liveness | `/health/live` | Only this process. Answers 200 while the event loop turns. |
| readiness | `/health/ready` (or `/health`) | Postgres, and reports the round-trip latency, not just reachable/unreachable. |
| deploy check | `/health/version` | `APP_VERSION`, `GIT_COMMIT`, environment, node version, start time. |

**Do not point a liveness probe at `/health`.** It was the only endpoint, and it
answers the readiness question — so a thirty-second Postgres failover would have
had the orchestrator restart every API process, discarding warm connections and
in-flight requests at exactly the moment the platform was already struggling.
The right response to an unreachable database is to stop taking traffic and keep
running.

Set `APP_VERSION` and `GIT_COMMIT` at build time. The first question during an
incident is "which build is this?", and answering it by reading a file over SSH
is how the wrong answer gets believed.

## Logging

Set `LOG_FORMAT=json` in production. Each line becomes one JSON object
carrying `requestId` — the same id the API returns in `request_id` on every
error body and in the `X-Request-Id` response header. A customer reads that
string off her error screen, support pastes it into a log search, and every
line of her request comes back. Without it, one process serving every customer
means interleaved lines and guesswork.

Credentials and **phone numbers** are redacted at any depth before a line is
written. The number is on that list because on this platform it *is* the
identity — sign-in is a code sent to it.

## Requiring an idempotency key

`IDEMPOTENCY_REQUIRED_ROUTES` is a comma-separated list of `METHOD /route/pattern`
entries that refuse a request arriving without an `Idempotency-Key`:

```
IDEMPOTENCY_REQUIRED_ROUTES=POST /orders/checkout
```

**Leave it empty until the app update carrying keys has reached your installs.**
The protection already works whenever a client sends a key, and the app now
does for checkout. Switching it on earlier refuses every older build — a woman
on last month's version could not buy anything. Once the update has propagated,
turning it on closes the gap for good rather than depending on the client to
remember.

## Authorization is fail-closed

`AuthorizationGuard` refuses any route that declares nothing. Every controller
must carry one of:

- `@Public()` — no session needed;
- `@Roles` / `@Authorize` / `@RequirePermissions` — the guard enforces it;
- `@SelfScoped('how the service enforces ownership')` — the rule depends on the
  row, and the reason names the check.

`route-classification.spec.ts` fails the build if a controller carries none of
them, so a new one cannot inherit "allowed" in silence.

## Running the test suite

```bash
cd backend && npm test
```

Concurrency is capped at four spec files at once, and that cap is load-bearing
rather than tidiness. `node --test` otherwise runs all 109 spec files in
parallel, each holding its own Prisma client and its own pool of database
connections. On a developer machine with 8 GB — especially with the API and the
Flutter web server also running — the workers are starved before they report
anything, and the run ends part-way with no failing test named. It looks
exactly like a broken suite and is not one.

If a run still struggles, `npm run test:serial` walks the files one at a time.
Slower, and it will finish.

**Do not run the suite with a dev server attached to the same database.** The
schedulers fire against it mid-run, and the two contend for the same rows.
