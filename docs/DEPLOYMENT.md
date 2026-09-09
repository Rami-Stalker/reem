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
