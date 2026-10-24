# Ohara on Supabase-hosted PostgreSQL

```
Flutter app ──HTTPS/WebSocket──▶ NestJS API (backend/) ──TLS──▶ PostgreSQL ── hosted by Supabase
                                        └──────────server-to-server──▶ Supabase Storage (upload bytes)
```

The NestJS API in `backend/` is the backend: every read and write, sign-in,
role and permission check, order, ledger posting, chat frame and scheduled job
goes through it. **Supabase is the host of its PostgreSQL database** (project
`reem`, ref `huvtblxudachirsjaqkx`, eu-central-1) and of the upload buckets.
The app never talks to Supabase and ships no Supabase key.

This replaced, on 2026-09-15, the deployment in which the same backend ran as a
Supabase Edge Function and the app used Supabase Auth and Realtime directly
([SUPABASE_EDGE_RETIRED.md](SUPABASE_EDGE_RETIRED.md)).

## 1. What uses what

| Concern | Where it runs |
| --- | --- |
| API (all routes, guards, policies, money logic) | NestJS — `npm run build && npm run start:prod` |
| Database | Supabase PostgreSQL 17, reached through the **transaction pooler** (port 6543) |
| Schema | Prisma migrations in `backend/prisma/migrations` — applied with `npm run db:pooled:deploy` |
| Sign-in (phone OTP), sessions, JWT refresh rotation, TOTP, step-up | NestJS `auth` module: `POST /auth/otp/login/start` → `/verify` |
| Roles & permissions | NestJS guards (`JwtAuthGuard` → `DeviceProofGuard` → `StepUpGuard` → `AuthorizationGuard`) |
| Media upload / private media | NestJS `POST /media/uploads`, `GET /media/:id/file`; bytes in Supabase Storage (`MEDIA_DRIVER=supabase`) |
| Public media delivery | Supabase Storage CDN URL of the public bucket (read-only, product/post photographs) |
| Chat live updates, presence, typing | NestJS WebSocket `/ws/chats` |
| 30 scheduled jobs | NestJS `JobRunner`, each run under a lease in `scheduled_job_states` — safe on any number of instances ([SCHEDULED_JOBS.md](SCHEDULED_JOBS.md)) |
| Secrets | `backend/.env` on the API host — never in the app, never in git |

## 2. Configuration (`backend/.env`)

See `backend/.env.example` for every variable; the ones this hosting adds:

| Variable | Value |
| --- | --- |
| `DATABASE_URL` | `postgresql://postgres.<ref>:<url-encoded password>@aws-0-eu-central-1.pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=10&pool_timeout=20&sslmode=require&sslcert=./certs/supabase-root-2021.crt&sslaccept=strict` |
| `MEDIA_DRIVER` | `supabase` |
| `SUPABASE_URL` | `https://<ref>.supabase.co` |
| `SUPABASE_SECRET_KEY` | the project's **secret** key (server only) |
| `SCHEDULER_ENABLED` | `true` (default); `false` only to keep timers off an instance — jobs are lease-locked either way |
| `TEST_DATABASE_URL` | a **local** database for `npm test` |
| `DATABASE_TRANSACTION_TIMEOUT_MS` / `_MAX_WAIT_MS` | only for an instance far from Frankfurt (default 5000 / 2000) |

Why each piece of the URL is there — all measured on this project:

- **Transaction pooler, not the direct host.** `db.<ref>.supabase.co` is
  IPv6-only, and the session pooler (5432) refuses connections from the
  development network. The pooler also multiplexes connections: the direct
  connection has 60 slots.
- **`pgbouncer=true`** — on the transaction pooler Prisma must not prepare
  named statements; without it the second request fails with
  `prepared statement "s0" already exists`. The API refuses to boot with a
  6543 URL missing it.
- **`sslmode=require&sslcert=…&sslaccept=strict`** — TLS verified against
  Supabase Root 2021 CA, committed at `backend/prisma/certs/supabase-root-2021.crt`
  (a public certificate; SHA-256 `80:70:25:AD:…:CA:FA`, valid to 2031-04-26).
  Without the CA the connection is rejected as untrusted, so verification is
  real. `sslcert` is resolved against `backend/prisma/`.
- **The keyring must not change.** `JWT_*`, `OTP_PEPPER`, `GUEST_TOKEN_PEPPER`,
  `OTP_DELIVERY_KEY` and `TOTP_ENC_KEY` in `backend/.env` are the values the
  data was written under (verified by SHA-256 against the retired function's
  secrets). Different values would sign everyone out and make every enrolled
  TOTP authenticator unreadable.

The boot also refuses `MEDIA_DRIVER=supabase` without `SUPABASE_URL` /
`SUPABASE_SECRET_KEY`, or with the publishable key put where the secret key
belongs.

## 3. Migrations

`prisma migrate deploy` cannot run over the transaction pooler (its schema
engine hangs there), so:

```bash
cd backend
npm run db:pooled:status   # read-only: pending migrations, drift, unfinished rows
npm run db:pooled:deploy   # apply pending migrations
```

`scripts/migrate-pooled.mjs` applies each pending migration in its own
transaction, records it in `_prisma_migrations` with Prisma's checksum, locks
new tables away from Supabase's Data API (`reem_supabase.lock_down_public()`),
and records it in Supabase's CLI ledger. It stops before any DDL if a migration
Prisma recorded is unfinished or an applied file was edited. Verified by
applying all 88 migrations to an empty database.

Create migrations as before (`npm run db:migrate` against a local database),
never against Supabase.

On 2026-09-15 the one pending migration, `20260915120000_product_social_and_feed_controls`
(four defaulted columns on `products`, five new tables — additive), was applied
this way. Nothing else in the schema changed.

## 4. Media

`MEDIA_DRIVER=supabase` selects `SupabaseStorageDriver`
(`backend/src/modules/media/storage/`):

- `reem-media-public` — product, post, story, avatar, logo images. Written by
  the API; served by Supabase's CDN at the absolute URL the API returns.
- `reem-media-private` — identity documents and chat attachments. No client
  policy at all; read only by the API and streamed by `GET /media/:id/file`
  after the per-purpose authorisation check.

Every existing file is where it was (the retired deployment wrote to the same
buckets, `driver = 'supabase'` on its rows), so nothing was copied or moved.
Resized WebP copies and blur hashes are generated again for new uploads — the
edge runtime could not load `sharp`; a server can.

The app attaches its bearer token to a private media URL only when the URL is
on the API's own origin — a chat attachment URL is text a sender wrote.

## 5. Sign-in

OTP is the backend's own: `POST /auth/otp/login/start` creates the challenge
and the outbox delivers it through WhatsApp → SMS → voice. **No provider
credentials are configured yet**, so today codes reach only:

- the development inbox (`OTP_DEV_INBOX_ENABLED=true`, refused in production), or
- the operations console transport (`AUTH_OPS_TRANSPORT_ENABLED`, closed beta
  only, refused in production).

Contracting a provider is environment variables only (`WHATSAPP_*` or `SMS_*`).
Until then a production build of the API cannot sign anyone in. Supabase Auth
is no longer involved; its test phone numbers do nothing for this API.

## 6. Scheduled jobs

The API runs all 30 jobs itself, each under a lease in `scheduled_job_states`
(migration `20260915180000_scheduled_job_states`), so any number of instances
may schedule them and exactly one runs each tick. Details, the audit of every
job, and why this beat pg_cron or an external cron: [SCHEDULED_JOBS.md](SCHEDULED_JOBS.md).

The retired deployment's 31 `pg_cron` jobs (`reem.*`, calling the Edge
Function) were **paused, not deleted**, on 2026-09-15 — while both ran, the
function claimed OTP codes the API had issued and failed to deliver them.

**Do not re-enable them while the API runs.** The Edge Function is the old
build: it does not take the leases, so every job would run twice again. Rolling
back to the function means stopping the API first, then:

```sql
select cron.alter_job(jobid, active := true) from cron.job where jobname like 'reem.%';
```

## 7. What remains in Supabase, and why

| Kept | Why |
| --- | --- |
| PostgreSQL + all data | It is the database. |
| Storage buckets `reem-media-public` / `reem-media-private` | Every uploaded file lives there; the API writes and reads them server-side. |
| Public bucket CDN | Public photographs are served from it — no API round trip for an image. |
| `reem_supabase` schema, RLS on every table | Row Level Security stays deny-by-default for Supabase's Data API. The API connects as the table owner and is unaffected. |
| Edge Function `api`, paused pg_cron jobs, Auth phone settings | Not used. Left in place as the rollback path; safe to remove once the NestJS host is live (see §8). |

Nothing in Supabase was deleted.

## 8. Before launch

1. **Host the API** in Frankfurt — prepared: `render.yaml` + `backend/Dockerfile`,
   see `docs/DEPLOYMENT.md` §Hosting. Measured from the development machine, a
   screen's request takes 1–12 s because every query crosses a slow link;
   in-region it is milliseconds per query.
2. **OTP provider** credentials (§5) — production now refuses to boot without one.
3. **Supabase Pro** for daily backups (the Free plan has none).
4. Privileged accounts without TOTP block a production boot
   (`PrivilegedMfaInvariant`). Checked 2026-09-15: the only active one,
   `reem_owner`, has TOTP — nothing to do unless staff accounts are added.
5. Optionally, in the Supabase dashboard: disable phone sign-ups and the Send
   SMS hook (Authentication), delete the `api` function and the paused
   `reem.*` cron jobs, and revoke the `reem-setup` access token.
6. Consider a dedicated database role for the API instead of `postgres`.

## 9. Verification (2026-09-15, against the live project)

See the final report in this change for the numbers; the checks are
reproducible with:

```bash
cd backend && npm run db:pooled:status          # schema in sync
curl http://127.0.0.1:3000/health               # {"database":"up"}
node supabase/edge/scripts/smoke-api.mjs --api http://127.0.0.1:3000 --login dev-inbox --commerce
flutter analyze && flutter test
```

(The smoke script's four checks for `/internal/cron`, `/auth/supabase/send-sms-hook`
and `/realtime/presence` target routes only the retired function served; a 404
from NestJS is the expected answer.)
