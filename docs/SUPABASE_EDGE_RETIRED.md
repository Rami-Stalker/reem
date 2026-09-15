# Reem on Supabase — the retired Edge Function deployment

> **Retired 2026-09-15.** This describes how the API *used to* run as a
> Supabase Edge Function, with the app calling Supabase Auth and Realtime
> directly. It is no longer how Reem runs: the NestJS API is the backend and
> Supabase hosts only its PostgreSQL database and upload bytes — see
> [SUPABASE.md](SUPABASE.md). The `api` function is still deployed but unused,
> and its 31 pg_cron triggers are paused. Kept as the record of that
> deployment and as a rollback path; the Flutter half of it
> (`BACKEND=supabase`, `supabase_flutter`) was removed from the app.

The Reem API runs on Supabase today, with no machine of our own. The backend in
`backend/` is **not** rewritten, forked or modified: the same NestJS
application is compiled into a Supabase Edge Function, and Supabase supplies
what a server used to — the database, sign-in codes, file storage, realtime
chat and the scheduler. Moving back to a server later is a deployment choice,
not a project (§9).

## 0. Live status — project `reem` (`huvtblxudachirsjaqkx`, Frankfurt)

Deployed and verified on 2026-09-14, against the real project, not a copy:

| Check | Result |
| --- | --- |
| Schema | 97 migrations applied; 206 tables, RLS on all; `_prisma_migrations` complete |
| Data | 109,502 rows / 205 tables imported, every count equal to the local database; media uploaded |
| Admin accounts | `aud_*` fixtures and demo `reem_admin` disabled (not deleted); `reem_owner` enrolled in TOTP; API boots with `NODE_ENV=production` |
| API end to end (`npm run smoke`, Supabase Auth sign-in) | **116/116** — three roles, catalogue, cart, checkout + cancel, content, follows, chat, notifications, commissions, delivery, admin, refusals |
| RLS (`tests/rls_roles.sql`) | **38/38** — anon, customer, seller, staff, unlinked session, re-assigned number |
| Realtime (`scripts/realtime-test.mjs`) | **6/6** — message delivered live to the other phone (~2–3 s incl. send), foreign topic refused, forged event not delivered |
| Storage + Send SMS hook (`scripts/storage-hook-test.mjs`) | **13/13** — public CDN read, private only via API to its owner, no direct bucket access, hook signature enforced |
| Concurrency | 300 simultaneous requests fired from inside Supabase's network: **300/300 HTTP 200**, no connection errors |
| Server time per request | ~1.0 s (Supabase starts a fresh isolate for nearly every request; ~0.65 s of that is booting the API) |
| Scheduled jobs | all 30 run through pg_cron; `ValueScheduler.collect` runs in slices (§7) |

## 1. What runs where

| Concern | On a server of our own (`backend/`, unchanged) | On Supabase (current) |
| --- | --- | --- |
| API (all ~670 routes, guards, policies, money logic) | `node dist/main.js` | Edge Function **`api`** — the same code, bundled by `supabase/edge` |
| Database | PostgreSQL 18, `prisma migrate deploy` | Supabase Postgres 17, **identical schema** (`supabase/migrations`, generated from the Prisma migrations) |
| Sign-in code (OTP) | `POST /auth/otp/login/*`, delivered by the backend | **Supabase Auth** phone OTP; delivered by the same backend transports through the **Send SMS hook** |
| Session | Reem JWT + device-bound refresh tokens | Unchanged — Supabase session is **exchanged** for the Reem session at `POST /auth/supabase/exchange` |
| Media files | `backend/storage/media` on disk | **Supabase Storage** buckets `reem-media-public` / `reem-media-private` |
| Chat live updates | WebSocket held by the API process | **Supabase Realtime** private channels (broadcast), authorised by RLS |
| 30 scheduled jobs | `@nestjs/schedule` timers | **pg_cron** → `POST /internal/cron/:job` (pg_net, shared secret in Vault) |
| Secrets & provider keys | `backend/.env` | **Edge Function secrets** (never in the app) |
| Direct client data access | none | Supabase Data API, **RLS deny-by-default** with a read-only role surface (§4) |

The Flutter app is one codebase for both. `--dart-define=BACKEND=supabase`
selects Supabase; without it the app talks to `API_BASE_URL` as before.

## 2. Why this shape

The backend is ~124k lines across 49 modules with a double-entry ledger,
escrow, COD trust scoring, returns, delivery carriers, intelligence engines and
an identity system with device-bound sessions and step-up. Re-implementing that
as SQL functions and hand-written Edge Functions would have produced a second
backend that drifts from the first on day one, and a long tail of regressions
in exactly the places money moves.

Instead the unmodified application runs on the edge. It was verified that:

- the whole application boots in Supabase's edge runtime with Prisma's WASM
  query compiler and the `pg` driver adapter (no native engine) — bundle
  **4.4 MB** (under the 5 MB limit for deploys without Docker; the 1.9 MB query
  compiler is loaded from Storage and verified by SHA-256), boot **~600 ms CPU**
  of the 2 s budget, ~58 MB memory;
- the schema built by `supabase/migrations` is **byte-identical** (pg_dump
  schema diff) to the one the Prisma migrations build locally;
- the full local dataset (**109,502 rows, 205 tables**) imports into that schema
  with every row count matching;
- the API smoke test — customer, seller and staff, catalogue, cart, **checkout
  and cancel**, content likes/comments, follows, favourites, chat, presence,
  notifications, commissions, delivery, admin, and role refusals — passes
  **110/110** against the edge build.

Five backend providers are replaced on the edge, each through a seam the
backend already had (`supabase/edge/src/edge-app.ts`):

| Provider | Replaced by | Why |
| --- | --- | --- |
| `MEDIA_STORAGE_DRIVER` | `SupabaseStorageDriver` | No disk in an isolate |
| `MediaService` (URLs only) | `EdgeMediaService` | Public files are served by Storage, private ones by the function |
| `ImageDerivativesService` | `EdgeImageDerivativesService` | libvips (sharp) cannot load on the edge — originals are served |
| `ChatRealtimeGateway` | `SupabaseRealtimeGateway` | No long-lived sockets; same events, published to Realtime |
| `OtpService` | `SupabaseAwareOtpService` | Accepts a one-request proof that Supabase Auth verified the phone |

Plus `ValueCollectorService` → `EdgeValueCollectorService` (the same sources
and recompute, run in slices; §7).

Runtime adjustments, none of them in `backend/`:

- **Entry through `Deno.serve`** (`runtime/deno-bridge.ts`): each Web request
  is handed to the Express app in memory.
- **Environment**: Supabase's runtime forbids writing `process.env`, and lacks
  Node globals (`Buffer`, `process.pid`, …) that libraries read at load; the
  bundle banner and `runtime/env.ts` provide them.
- **Database**: one connection per isolate, through the **transaction pooler**
  (`REEM_DATABASE_URL`, port 6543) with TLS pinned to Supabase's root CA
  (`runtime/supabase-ca.ts`). The direct connection ran out of Postgres's 60
  slots under 30 simultaneous phones.
- **Timers and background work** (`runtime/patches.ts`): cron timers are not
  started; post-response event listeners are kept alive with
  `EdgeRuntime.waitUntil`.
- **Start-up writes deferred** (`runtime/boot-seeds.ts`): the mission
  catalogue upsert and default-carrier check run once per deploy
  (`POST /internal/cron/boot-seeds`) instead of on every isolate.
- **Size**: `argon2` → hash-wasm's argon2 build; `sharp` → unavailable shim;
  `iconv-lite`, `cron`, `mime-db`, `libphonenumber-js/max` → small shims.
- **Image search** answers `IMAGE_ENGINE_UNAVAILABLE` (`runtime/image-engine.ts`)
  instead of blaming the photograph; set `REEM_IMAGE_ENGINE=available` once a
  real image engine replaces the sharp shim.

## 3. Repository layout

```
supabase/
  config.toml                  local stack + function config (api: verify_jwt = false)
  migrations/
    2026…_<prisma name>.sql    87 files GENERATED from backend/prisma/migrations
    20260914120000_reem_supabase_identity.sql   identity links + RLS helper functions
    20260914120100_reem_supabase_rls.sql        RLS on every table, role read policies
    20260914120200_reem_supabase_storage.sql    the two buckets
    20260914120300_reem_supabase_realtime.sql   realtime.messages policies
    20260914120400_reem_supabase_cron.sql       GENERATED pg_cron schedule (30 jobs)
  functions/api/index.ts       entry; imports the generated reem-api.mjs (git-ignored)
  edge/                        the build and the Supabase adapters
    build.mjs                  tsc (backend + adapters) → Prisma edge client → esbuild bundle
    src/                       adapters (runtime, storage, identity, realtime, scheduling)
    scripts/                   baseline, cron SQL, secrets, data migration, smoke & load tests
  tests/rls_roles.sql          RLS assertions per role
```

`backend/` is only ever read by the build.

## 4. Security model

- **The app ships no secret.** It carries the project URL and the *publishable*
  key (public by design). `BackendConfig` refuses to build if a secret or
  service-role key is passed as the publishable key.
- **All business logic and all writes run server-side** in the `api` function,
  under the backend's own guards: `JwtAuthGuard` → `DeviceProofGuard` →
  `StepUpGuard` → `AuthorizationGuard`, role policies and ownership checks.
  Commissions, orders, ledger, returns, delivery integrations and admin actions
  never leave that path.
- **Row Level Security** protects everything reachable with the publishable key:
  - RLS is enabled on **every** table in `public`; `anon`/`authenticated` hold
    **no privileges** except a read-only surface, and nothing is writable.
  - Read surface: active catalogue (`categories`, `brands`, `products`,
    `product_media`, `product_variants`, `seller_offers`) for everyone; her own
    `orders`, `seller_orders`, `order_items`, `notifications`, `chats`,
    `chat_participants`, `messages`, `message_attachments`, `follows`;
    sellers see their own sub-orders and offers in any state; staff read orders
    and products platform-wide (not other people's notifications).
  - The Supabase user maps to a Reem user only through
    `reem_supabase.identity_links`, and only while the auth user's phone still
    equals the account's phone — a number that changes hands carries nothing.
  - Tables added by future Prisma migrations are locked down automatically
    (`reem_supabase.lock_down_public()` runs at the end of each mirrored file).
- **Storage**: both buckets are written only by the function; `storage.objects`
  has no client policy. Public objects are readable at their public URL;
  private objects only through `GET /media/:id/file` after authorisation.
- **Realtime**: private channels only. `reem:user:<id>` is join-only for that
  user and publish-only for the server; `reem:chat:<id>` is limited to members.
  No table is added to the realtime publication.
- **Cron** calls carry a secret held in Vault and in the function's secrets.
- **Send SMS hook** requests are verified (Standard Webhooks HMAC) before use.

Run `supabase/tests/rls_roles.sql` in the SQL editor to see every assertion pass
(it creates and removes its own fixtures).

## 5. First deployment

Prerequisites: Node 18+, `backend/` dependencies installed (`npm install` in
`backend/`), PostgreSQL client tools (`psql`, `pg_dump`) — the local
PostgreSQL 18 install has them.

```bash
cd supabase/edge
npm install
```

1. **Create the Supabase project** (region close to Syria, e.g. `eu-central-1`
   Frankfurt), keep the database password.
2. **Link and push the schema**
   ```bash
   npx supabase login
   npx supabase link --project-ref <ref>
   npx supabase db push
   ```
3. **Edge Function secrets**
   ```bash
   npm run secrets:env -- --cors https://<web origin, if any>
   npx supabase secrets set --env-file ../.env.edge --project-ref <ref>
   ```
   Then delete `supabase/.env.edge`. Add `SEND_SMS_HOOK_SECRET` after step 6.
4. **Vault** (SQL editor) — the two values printed by `secrets:env`:
   ```sql
   select vault.create_secret('<REEM_CRON_SECRET>', 'reem_cron_secret');
   select vault.create_secret('https://<ref>.supabase.co/functions/v1/api', 'reem_api_url');
   ```
5. **Build and deploy the API** (no Docker needed)
   ```bash
   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SECRET_KEY=<secret key> \
   REEM_CRON_SECRET=<cron secret> npm run deploy -- --project-ref <ref>
   ```
   Builds, uploads the query compiler to `reem-runtime`, deploys `api` with
   server-side bundling, and runs the start-up seeds. Also set
   `REEM_DATABASE_URL` (transaction pooler URL, port 6543, with the database
   password) as a function secret.
6. **Auth settings** (Dashboard → Authentication):
   - *Sign In / Providers → Phone*: enable phone sign-in and signups;
     enable phone confirmations.
   - *Hooks → Send SMS hook*: HTTPS,
     `https://<ref>.supabase.co/functions/v1/api/auth/supabase/send-sms-hook`,
     generate the secret, and store it:
     `npx supabase secrets set SEND_SMS_HOOK_SECRET="v1,whsec_…"`.
   - *Phone → Test phone numbers* (closed beta / QA only): e.g.
     `963933333333=<code>`, `963922222222=<code>`, `963911111111=<code>`.
     Remove them before public launch.
   - *Rate limits*: keep SMS sends per hour conservative (WhatsApp costs money).
7. **Import the data**
   ```bash
   npm run data:export
   SUPABASE_DB_URL="postgresql://postgres.<ref>:<password>@<session-pooler-host>:5432/postgres" \
   SUPABASE_URL="https://<ref>.supabase.co" SUPABASE_SECRET_KEY="<secret key>" \
   npm run data:import
   ```
   Then delete `supabase/.temp/reem-data.sql` (it contains customer data).
8. **Verify**
   ```bash
   npm run smoke -- --api https://<ref>.supabase.co/functions/v1/api --login supabase \
     --supabase-url https://<ref>.supabase.co --publishable-key <publishable key> --otp <test code>
   npm run load -- --api https://<ref>.supabase.co/functions/v1/api --login supabase \
     --supabase-url https://<ref>.supabase.co --publishable-key <publishable key> --otp <test code> --devices 30
   ```
   and run `supabase/tests/rls_roles.sql` in the SQL editor.
9. **Build the app**
   ```bash
   flutter build apk --release --dart-define=APP_ENV=production \
     --dart-define=BACKEND=supabase \
     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
     --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>
   ```

### Notes from the first real deployment (project `reem`, `huvtblxudachirsjaqkx`, eu-central-1)

- **Local bundling needs Docker.** `--use-api` (server-side bundling) caps a
  function at 5 MB; the API is ~8 MB, so the CLI must bundle locally, which it
  does inside the `supabase/edge-runtime` Docker image (20 MB limit).
- **Connect through the transaction pooler** (`aws-0-eu-central-1.pooler.supabase.com:6543`)
  for `db push`, psql and the data import; the session pooler on 5432 refused
  connections from this network while the project was new.
- **The CLI validates `config.toml` before every command**, so
  `SEND_SMS_HOOK_SECRET` must be set in the environment (any valid
  `v1,whsec_…` value) even for commands unrelated to Auth.
- **Auth was configured through the Management API**
  (`PATCH /v1/projects/<ref>/config/auth`): phone on, email off, OTP 6 digits /
  10 minutes / one per 60 s, Send SMS hook → the `api` function, and test
  numbers with `sms_test_otp_valid_until` a week out, so fixed codes expire on
  their own and never reach production.
- **Admin accounts in the Supabase copy**: the four `aud_*` audit fixtures and
  the demo seed admin `reem_admin` (published password) were *disabled*, not
  deleted; `reem_owner` enrolled TOTP through a page served only on
  `127.0.0.1`, so neither the setup key nor any code passed through a chat or a
  log. The local database was not changed.
- **From a laptop, Postgres TLS** to the pooler needs Supabase's CA
  (or `sslmode=no-verify` for a local one-off); deployed functions are already
  configured.

### Before `NODE_ENV=production` will boot

The backend refuses to start in production while a privileged account
(`SUPER_ADMIN`, `OPERATIONS_ADMIN`, …) has no confirmed TOTP authenticator
(`PrivilegedMfaInvariant`). Enrol each staff account (`POST /auth/totp/enroll`
from the app) or disable the ones that are not real people, before deploying.
The function answers `503 The API failed to start` and logs the list otherwise.

## 6. Configuration reference

**Injected by Supabase** (do not set): `SUPABASE_URL`, `SUPABASE_DB_URL`,
`SUPABASE_SERVICE_ROLE_KEY` / `SUPABASE_SECRET_KEYS`, `SUPABASE_ANON_KEY` /
`SUPABASE_PUBLISHABLE_KEYS`.

**Required secrets**: `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `OTP_PEPPER`,
`GUEST_TOKEN_PEPPER`, `OTP_DELIVERY_KEY`, `TOTP_ENC_KEY` (the *same* values as
`backend/.env` — the migrated data is encrypted/hashed with them),
`REEM_CRON_SECRET`, `SEND_SMS_HOOK_SECRET`, `CORS_ORIGINS`, `NODE_ENV`.

**Provider credentials** (as the backend documents them): WhatsApp Cloud
(`WHATSAPP_*`), SMS gateway (`SMS_*`), voice (`VOICE_*`), delivery carriers
(each carrier's credential variables, e.g. `ACME_API_KEY`), AI stylist
(`AI_STYLIST_*`), trend LLM (`TREND_LLM_*`), vision (`VISUAL_VISION_*`),
push (`PUSH_*`), FX (`FX_*`).

**Edge-only knobs**: `REEM_DATABASE_URL` (override the DB URL, e.g. a
transaction-pooler URL), `REEM_DB_POOL_SIZE` (default 4 per isolate),
`REEM_LOG_LEVELS` (default `error,warn`), `REEM_BOOT_METRICS=true` (log cold
start CPU), `TRUST_PROXY` (default `true`).

**Flutter**: `BACKEND=supabase`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`,
optional `SUPABASE_API_FUNCTION` (default `api`).

## 7. Differences from a single server, and known limits

| Topic | On Supabase |
| --- | --- |
| Cold starts | Measured: Supabase starts a fresh isolate for nearly every request — even a trivial test function was never reused — so each API call pays the API's boot (~0.65 s) and lands at ~1.0 s server time. Parallel calls boot in parallel. The app's HTTP cache (stale-while-revalidate) hides most of it on repeat screens. A server of our own answers warm requests in tens of milliseconds. |
| In-memory cache (`CacheService`) | Lives only as long as one request, so it rarely helps on Supabase; correctness is unaffected (prices charged at checkout are always read from the database). |
| CPU per invocation | 2 s, all plans. `ValueScheduler.collect` needs more in one go, so it runs in slices saved in `reem_supabase.job_progress`, continued every minute; a slice that exceeds the budget three times is skipped and logged (today the *community* evidence source, which records up to ~1,000 events in one backend loop). The nightly intelligence jobs (trends, graph, market, seller/admin intelligence) are switched off in the backend's own configuration today; if their `*_SCHEDULER_ENABLED` flags are turned on, check their logs for `WORKER_RESOURCE_LIMIT` — they may need the same slicing or a server. |
| Database connections | One per isolate, through the transaction pooler; never point `REEM_DATABASE_URL` at the direct connection (60 slots). |
| Rate limiting (`ThrottlerGuard`) | Counted per isolate, so looser than on one server. OTP attempts and sends are also limited in the database and by Supabase Auth. |
| Image resizing / blur hashes | Not generated (no libvips); originals are served, and every URL the API hands out already falls back to the original. The code is intact: to add it back, replace the `sharp` shim in `build.mjs` with a WASM image library (or Supabase image transformations on Pro) and remove the `ImageDerivativesService` override. |
| Visual search by photograph | Switched off with an honest `IMAGE_ENGINE_UNAVAILABLE` (bootstrap reports `ready: false`); the rest of search and "similar products" from stored vectors work. The code is intact; the same image engine as above plus `REEM_IMAGE_ENGINE=available` brings it back. |
| Match code in sign-in messages | Supabase generates the code, so the two-digit anti-relay match code is not shown for sign-in (step-up and phone-change codes still carry it). |
| Upload size | 50 MB per file on the Free plan (backend allows 64 MB video). |
| Scheduled job times | pg_cron runs in UTC; schedules were shifted −3 h so they fire at the same Damascus time. "Today" boundaries computed in code are UTC days on the edge. |
| Legacy WebSocket `/ws/chats` | Not served; the Supabase build of the app uses Realtime. |

## 8. Changing things

- **Backend code change** → `npm run build` and redeploy `api`.
- **New Prisma migration** → `npm run baseline` (mirrors it into
  `supabase/migrations`), `npx supabase db push`, rebuild and redeploy.
- **New or changed `@Cron`** → run the function locally or on the project and
  `npm run cron:sql -- --from <api url> --secret <REEM_CRON_SECRET>`, then push.
- **Run the edge build locally** (Deno 2):
  `deno run -A --env-file=<file> supabase/functions/api/index.ts` with
  `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `REEM_DATABASE_URL` and the
  keyring set; `NODE_ENV=development` enables the dev OTP inbox for
  `npm run smoke -- --login dev-inbox`.

## 9. Going back to a server of our own

Nothing in `backend/` depends on Supabase, and nothing was removed from it.

1. **Database** — either point the backend at the Supabase database
   (`DATABASE_URL` = session-pooler URL; `_prisma_migrations` is already
   populated, so `prisma migrate deploy` reports it up to date), or move the
   data home: `pg_dump --data-only --schema=public` from Supabase into a
   database built by `npx prisma migrate deploy`. The extra `reem_supabase`
   schema is invisible to Prisma and can be ignored.
2. **Media** — download both buckets into `storage/media/public` and
   `storage/media/private` (same keys), then set `media_assets.driver = 'local'`
   and replace the Storage URL prefix in URL columns with `/media/files/`
   (the inverse of `scripts/migrate-data.mjs import`).
3. **Run** — `npm run build && npm run start:prod` with the same keyring in
   `.env`. Cron timers, the WebSocket chat and the OTP login routes are the
   backend's own and work as before.
4. **App** — build without `BACKEND=supabase`, with
   `--dart-define=API_BASE_URL=https://api.<domain>`.
5. **Optional** — turn off the Supabase project, or keep Supabase Auth by
   deploying `supabase/edge` routes alongside; not required.
