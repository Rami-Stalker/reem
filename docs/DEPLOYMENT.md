# Deployment

## Production architecture

```
 Flutter app ──HTTPS / WSS──▶ Reem API (NestJS, one always-on container, Frankfurt)
                                  │   REST · chat WebSocket · 30 lease-locked scheduled jobs
                                  │
                                  ├──TLS, transaction pooler :6543──▶ PostgreSQL  (Supabase `reem`, Frankfurt)
                                  └──HTTPS, secret key (server only)─▶ Storage buckets (Supabase `reem`)
 Uptime monitor ──▶ /health/ready, /health/jobs
```

The app talks only to the API. Supabase hosts the database and the upload
bytes; nothing in the app holds a Supabase key.

## Render Free (trial and first launch)

`render.yaml` is set to `plan: free`. Supabase keeps the database and the
files; Render runs only the NestJS container.

| | |
| --- | --- |
| Service | Web service, Docker (`backend/Dockerfile`), region Frankfurt |
| Start command | none to enter — the image's `CMD ["node", "dist/main.js"]` |
| Port | `$PORT` from Render (10000 by default), bound on `0.0.0.0` |
| Health check path | `/health/ready` — 200 only when PostgreSQL answers |
| Jobs monitor | `/health/jobs` — for your own checks; not the health check |
| Migrations | not run by Render on Free (no pre-deploy command): `cd backend && npm run db:pooled:status` / `db:pooled:deploy` from a machine with `backend/.env`, **before** pushing code that needs them. None pending on 2026-09-15. |

### What Free changes, and why it is still correct

- **Sleep after 15 min without a request or socket message; ~1 min to wake.**
  The app retries reads (timeouts, 502/503/504) and writes that carry an
  idempotency key; the chat socket waits up to 90 s for a handshake and then
  retries with backoff. A plain write sent into a waking instance can time out
  once — the same as a dropped connection, already shown as a retryable error.
- **Scheduled jobs** do not run while asleep and catch up on waking —
  [SCHEDULED_JOBS.md §On a host that sleeps](SCHEDULED_JOBS.md#on-a-host-that-sleeps-render-free).
- **Chat** is closed with 1001 when the instance stops; the app reconnects,
  rejoins its conversations and fetches what it missed.
- **Disk is temporary**: uploads never touch it (Supabase Storage).
- **A tenth of a CPU**: start-up is slower and image resizing on upload takes
  longer. `DATABASE_TRANSACTION_TIMEOUT_MS=15000` gives checkout room.
- **750 free instance-hours a month per workspace**: one always-running service
  uses ~744 in a 31-day month. Hours asleep are not counted.
- **No keep-awake pings.** They would turn Free into an unreliable imitation of
  Starter. When the service must be always on, set `plan: starter` ($7/month).

### Environment variables to enter

Values marked *existing* come from the current `backend/.env` — copy them
exactly; do **not** generate new ones.

| Variable | Required | Value |
| --- | --- | --- |
| `DATABASE_URL` | yes | existing — Supabase transaction pooler URL (port 6543, `pgbouncer=true`, `sslmode=require&sslcert=./certs/supabase-root-2021.crt&sslaccept=strict`) |
| `SUPABASE_SECRET_KEY` | yes | existing — the project's secret key |
| `JWT_ACCESS_SECRET` | yes | existing |
| `JWT_REFRESH_SECRET` | yes | existing |
| `OTP_PEPPER` | yes | existing |
| `GUEST_TOKEN_PEPPER` | yes | existing |
| `OTP_DELIVERY_KEY` | yes | existing |
| `TOTP_ENC_KEY` | yes | existing |
| `CORS_ORIGINS` | yes | the web origins allowed to call the API, comma-separated (not `*`). The mobile app sends no Origin; with no web build yet, the service's own URL, e.g. `https://reem-api.onrender.com`. |
| `SYROTP_ENABLED` + `SYROTP_BASE_URL` + `SYROTP_SECRET_KEY` + `SYROTP_RECEIVER_ID` (+ `SYROTP_PRIMARY`, `SYROTP_EXCLUSIVE`, `SYROTP_TIMEOUT_MS`) | satisfies the provider requirement on its own | reverse SMS through a self-hosted SYROTP instance — **the only rail when set**: an unreachable provider answers 503 instead of falling back, so while it is down nobody can sign in. `SYROTP_EXCLUSIVE=false` puts the transport chain back behind it. All four are required together and a half-set group is refused at boot; `SYROTP_BASE_URL` must be `https://` in production, because it carries a bearer token and single-use bind messages. `SYROTP_PRIMARY=false` demotes it behind the chain without a code change. See [REVERSE_SMS_OTP.md](REVERSE_SMS_OTP.md). |
| `SMS_GATEWAY_URL` + `SMS_GATEWAY_KEY` (+ `SMS_SENDER_ID`, `SMS_BODY_TEMPLATE`) | one provider is required | from the SMS provider — or instead `WHATSAPP_PHONE_NUMBER_ID` + `WHATSAPP_ACCESS_TOKEN` (+ `WHATSAPP_TEMPLATE_NAME`, `WHATSAPP_TEMPLATE_LOCALE`, `WHATSAPP_APP_SECRET`, `WHATSAPP_VERIFY_TOKEN`), or `VOICE_OTP_URL` + `VOICE_OTP_KEY` |
| `OTP_TEST_ACCOUNTS` + `OTP_TEST_ACCOUNTS_UNTIL` | temporary, instead of a provider | fixed login codes for the existing test accounts only, as `+phone:code,+phone:code`, and an ISO deadline at most 30 days out. Nothing is sent to those numbers; every other number still needs a real provider. When the deadline passes the codes stop working and a production boot again requires a provider. Remove both once SMS/WhatsApp is live. |
| `PAYMENT_BANK_TRANSFER_INSTRUCTIONS`, `PAYMENT_HAWALA_INSTRUCTIONS` | no — but a transfer rail is offered only when its variable is set | who the customer pays and what finance matches against (account, beneficiary name, office), shown to her as written. Finance confirms or rejects each transfer from the finance console. |
| `MEDIA_PUBLIC_ORIGIN` | no | leave unset on `onrender.com` (Render's `RENDER_EXTERNAL_URL` is used); set to `https://<custom domain>` once one is attached |
| `NODE_ENV`, `TRUST_PROXY`, `LOG_FORMAT`, `SCHEDULER_ENABLED`, `MEDIA_DRIVER`, `SUPABASE_URL`, `DATABASE_TRANSACTION_*` | set by `render.yaml` | — |
| `JOBS_TRIGGER_SECRET` | generated by Render | — |
| `PORT`, `RENDER_EXTERNAL_URL`, `RENDER_GIT_COMMIT` | set by Render | — |

Must **not** be set in production (the API refuses to boot):
`OTP_DEV_INBOX_ENABLED`, `OTP_DEV_ECHO`, `AUTH_OPS_TRANSPORT_ENABLED`,
`PAYMENTS_SANDBOX_CONFIRMATION`. Also leave out `TEST_DATABASE_URL` and
`MEDIA_LOCAL_*` — they belong to a developer machine.

### Steps in the Render Dashboard

1. Push the branch that contains `render.yaml` and `backend/` to GitHub, and
   merge it into `main` (or change `branch:` in `render.yaml` to the branch you
   deploy).
2. Render → **New → Blueprint** → connect GitHub → pick `Rami-Stalker/reem`.
3. Render shows the `reem-api` service from `render.yaml` and asks for each
   `sync: false` variable: paste the values from the table above.
4. **Apply**. Render builds the Docker image and starts it; the deploy is live
   when `/health/ready` answers 200.
5. Open `https://<service>.onrender.com/health/ready` → `{"status":"ok","database":"up"}`,
   then `/health/jobs`, and `/health/version` (shows the deployed commit).
6. Stop the API on the laptop (two schedulers are safe, two chat servers are not).
7. Build the app against it:
   `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://<service>.onrender.com`
   — install `app-arm64-v8a-release.apk`; see “App size” in the README for why.

If the deploy fails, the log names the reason: the environment validation lists
every missing or refused variable at once.

## Hosting

### When it must be always on: Render Starter, Frankfurt, 0.5 CPU / 512 MB

The same `render.yaml` with `plan: starter` (and, optionally, the
`preDeployCommand` above). The image is `backend/Dockerfile` and runs as-is on
any other container host.

Why this host, for this platform:

| Requirement | How it is met |
| --- | --- |
| Runs 24/7, never sleeps | Paid instances do not spin down. (The free instance sleeps after 15 minutes without traffic and is refused here: no timers, no sockets while asleep.) |
| Next to the database | Region `frankfurt`, the same as Supabase `reem`. Measured from a laptop in the region, one screen took 1–12 s because every query crossed a slow link; in-region it is milliseconds per query. |
| WebSockets | Supported on web services, no extra configuration. |
| Deploys without dropping requests | Zero-downtime deploys gated on `/health/ready`; the old container gets SIGTERM and `maxShutdownDelaySeconds: 45` to finish jobs and close sockets with 1001. |
| Migrations | On a paid plan, add `preDeployCommand: node scripts/migrate-pooled.mjs --apply` to `render.yaml` so they run before a new version takes traffic. |
| Little to operate | Managed TLS, logs, secrets and GitHub auto-deploy; no server to patch. |
| Cost | $7/month for the instance. |

Alternatives that fit the same image:

- **Fly.io** — shared-cpu-1x 1 GB in `fra` ≈ $7/month (512 MB ≈ $4). More
  memory for the money; deploys through its CLI; set `auto_stop_machines =
  "off"` and `min_machines_running = 1` or it scales to zero.
- **A VPS** (e.g. a small Hetzner instance in Germany, a few euros a month) —
  most resources per euro, but TLS, OS updates, restarts and deploys become
  yours to run.

### Memory

The API idles at ~150 MB. `NODE_OPTIONS=--max-old-space-size=384` in the image
keeps V8 under the 512 MB ceiling with room for image processing outside the
heap. If the host reports memory restarts (large photograph uploads in
parallel), move to 1 CPU / 2 GB (`plan: 1c-2g`, $25/month) — a one-line change.

### What stays on the platform's side, not in code

| Item | Where |
| --- | --- |
| Secrets | Render environment (the `sync: false` entries). The **auth keyring must be the existing values** from the current `backend/.env` — see `render.yaml`. |
| Custom domain + TLS | Render → Settings → Custom Domains. Then set `MEDIA_PUBLIC_ORIGIN` and `CORS_ORIGINS` to it, and build the app with `--dart-define=API_BASE_URL=https://<domain>`. |
| Uptime monitoring | Any external monitor (UptimeRobot, Better Stack…) on `GET /health/ready` (API down) and `GET /health/jobs` (a critical job stopped). Alerting only — never used to keep anything awake. |

### Supabase plan

The Free plan pauses a project after a week of inactivity (an always-on API
keeps it active) but **includes no backups**. Production needs **Pro, $25/month**:
daily backups kept 7 days, no pausing, 8 GB database (the database is 86 MB
today). Point-in-time recovery is a separate add-on ($100/month per 7 days) —
worth it once money volume justifies an RPO better than a day.

### Monthly cost at launch

| Item | Cost |
| --- | --- |
| Render web service, 0.5 CPU / 512 MB | $7 |
| Supabase Pro | $25 |
| SMS / WhatsApp OTP provider | per message, contract-dependent |
| **Total fixed** | **≈ $32/month** |

Upgrade paths, none of which changes code: 1 CPU / 2 GB instance ($25); a
worker instance for the analytics jobs (+$7); Supabase compute add-ons.

## Instances

**Run one API instance.** Scheduled jobs are now safe on any number — each
takes a lease in `scheduled_job_states` ([SCHEDULED_JOBS.md](SCHEDULED_JOBS.md))
— but three things still live inside the process:

| What is shared in-process | What a second instance does to it |
| --- | --- |
| **`ChatRealtimeGateway`** — WebSocket server with no pub/sub | A message never reaches a woman connected to a different instance. |
| **`CacheService`** — a `Map` per process | Two customers see two versions of the catalogue; an invalidation on one instance leaves the other stale. |
| **`ThrottlerGuard`** — in-memory storage | The rate limit multiplies by the number of instances. |
| **`EventEmitter2`** — in-process events | Listeners on the other instance never fire (chat broadcasts, notifications fan-out). |

A zero-downtime deploy briefly runs two containers; that is safe now — jobs are
leased, and the old container closes its sockets so apps reconnect to the new
one.

### What more instances would require

1. Redis (or Postgres `LISTEN/NOTIFY` through a session connection) for chat
   pub/sub and cross-instance events, and shared cache and throttler storage.
2. Nothing for jobs: done. Optionally a dedicated worker instance
   (`SCHEDULER_ENABLED=true` there, `false` on the API instances).
3. Nothing for uploads: Supabase Storage already serves every instance.

## Chat WebSocket in production

`wss://<api host>/ws/chats`, served by the same process as the REST API — no
separate service, no extra port. What makes it hold up on a hosted platform:

| Concern | Behaviour |
| --- | --- |
| Authentication | The access token rides in `Sec-WebSocket-Protocol` (never the URL). Checked at the handshake, then every 60 s: signing out, revoking a device or disabling an account closes the socket within a minute. |
| Authorisation | Joining, typing and marking read each check membership of the conversation; messages go through the same `ChatsService` as HTTP. |
| Idle proxies | The server pings every 25 s, below every common proxy idle timeout (60–100 s). The app's WebSocket answers pongs on its own. |
| Dead connections | No frame and no pong for 65 s → the server closes the socket and marks her offline. A phone that loses signal no longer stays "online" for hours. Verified: a silent client was dropped after 89 s and its presence flipped to `OFFLINE`. |
| Restarts & deploys | Shutdown closes every socket with **1001**; presence rows left by a crashed process are cleared at start-up. |
| Reconnection (app) | `ChatRealtimeService` reconnects on any drop with backoff 1 → 30 s plus jitter, reads the token afresh each attempt, re-joins open conversations, reconnects immediately when the app returns to the foreground, and emits `connection.restored` so the screens fetch what was sent while it was down. |
| Abuse | Frames over 64 KB close the socket (1009); more than 120 frames in 10 s closes it (1008). |
| Scale | One instance (no cross-instance pub/sub) — see §Instances. |

Nothing here depends on traffic keeping an instance awake: the host runs the
process continuously, and the heartbeat exists for connection health, not for
the platform's sleep timer.

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
- **no OTP provider** (a complete `SYROTP_*` group, `SMS_GATEWAY_URL`+`SMS_GATEWAY_KEY`, `WHATSAPP_PHONE_NUMBER_ID`+`WHATSAPP_ACCESS_TOKEN`, or `VOICE_OTP_URL`+`VOICE_OTP_KEY`) — nobody could sign in. At start-up `OtpDeliveryReadiness` also refuses when no *enabled* route in `otp_transport_routes` has a configured provider.
- `MEDIA_DRIVER=local` — uploads on a container disk vanish on the next deploy (`MEDIA_LOCAL_PERSISTENT=true` only with a mounted volume)
- a Supabase `DATABASE_URL` without `sslmode=require`, or on the transaction pooler without `pgbouncer=true`
- `MEDIA_DRIVER=supabase` without `SUPABASE_URL` / `SUPABASE_SECRET_KEY`, or with the publishable key in its place

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

**On Supabase, the first line of defence is the platform's own daily backup**
— which the Free plan does not include. Production runs on Pro (7 daily
backups), and the script below remains the independent, restorable copy kept
somewhere other than Supabase.

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
| deploy check | `/health/version` | `APP_VERSION`, `GIT_COMMIT` (or the host's `RENDER_GIT_COMMIT`), environment, node version, start time. |
| jobs monitor | `/health/jobs` | The run record in `scheduled_job_states`: 503 when a critical job is overdue or failing. **For an external monitor only** — never the host's health check, or a nightly job that missed a run blocks every deploy. |

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

**The suite never touches a remote database.** `npm test` preloads
`scripts/test-database-guard.js`, which points the integration specs at
`TEST_DATABASE_URL` and refuses any `DATABASE_URL` that is not on this machine
(the specs then skip). Some specs commit fixtures and delete them afterwards; a
run interrupted against the production database leaves them behind — it
happened once.
