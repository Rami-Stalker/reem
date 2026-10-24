# Ohara API — NestJS

Production-grade REST API for the **Ohara** women-focused social-commerce platform.

## Stack

- **Node.js 18+** · **TypeScript** · **NestJS 10**
- **PostgreSQL** · **Prisma ORM**
- **JWT** access + refresh tokens (one-time-use rotation) · **bcrypt** passwords
- **class-validator** DTOs · **Helmet** · **CORS** · **@nestjs/throttler** rate limiting
- **Phone-based** identity · roles **ADMIN / SELLER / CUSTOMER**

## Architecture

```
src/
  main.ts                  # bootstrap: helmet, CORS, global ValidationPipe + exception filter
  app.module.ts            # wiring + global guards (Throttler → JwtAuth → Roles)
  config/                  # typed configuration + env validation (fail-fast)
  prisma/                  # PrismaService (@Global)
  common/
    decorators/            # @CurrentUser, @Roles, @Public, @OptionalAuth
    guards/                # JwtAuthGuard, OptionalJwtAuthGuard, RolesGuard
    filters/               # AllExceptionsFilter (HTTP + Prisma -> uniform envelope)
    serializers/           # snake_case response mappers (contract parity)
    dto/                   # shared pagination
  modules/
    auth/                  # controller + service + repository + token.service + jwt.strategy + dto
    users/                 # profile: view/edit, stats, seller stats, follow/unfollow
    products/ posts/ stories/ orders/ favorites/ chats/ settings/ admin/ health/
```

**Security model.** Every route requires a valid access token by default (global `JwtAuthGuard`).
Opt out with `@Public()`; use `@OptionalAuth()` for public-but-personalised routes (e.g. product
browsing that adds `is_liked` when signed in). Role rules via `@Roles(UserRole.ADMIN)` + `RolesGuard`.

## Quick start

```bash
npm install
npm run db:setup:demo         # migrate + generate + seed (see docs/DATABASE.md)
npm run dev                   # http://localhost:3000
```

`db:setup:demo` expects PostgreSQL on `localhost:5432`. On this machine that is the
native Windows service; `docker compose up -d` starts the fallback on **5433**
instead. Provisioning the role and database is a one-off:
`npm run db:provision`.

Health: `GET http://localhost:3000/health`

## Demo data

The seed produces a full showcase dataset — ~165 products with competing seller
offers, a social feed, ~65 orders spanning every sub-order state, and the
finance, analytics and back-office rows the dashboards read. It is
deterministic, and every displayed counter equals real rows. See
[docs/DATABASE.md](../docs/DATABASE.md#the-demo-dataset).

`SEED_DEMO=false npm run db:seed` seeds only the reference data.

## Demo accounts (after seed) — phone / password

The seeded accounts carry a password, but a password alone will not sign you in
on a fresh handset: `POST /auth/login` refuses an unenrolled device and sends a
code instead. In development set `OTP_DEV_ECHO=true` and read the code out of
the server log (`[dev-echo] LOGIN code for +963…: NNNNNN`), or enable the ops
console with `AUTH_OPS_TRANSPORT_ENABLED=true`. Either way the fastest path is
`POST /auth/otp/login/start` then `/verify` — no password involved.


| Role     | Phone                             | Password      |
|----------|-----------------------------------|---------------|
| Admin    | `+966500000001`                   | `Admin123!`   |
| Sellers  | `+966500000002`, `+963931000101`… | `Seller123!`  |
| Shoppers | `+966500000005`, `+963932000201`… | `Password123!`|

## Identity model

Identity is the **phone number**, canonical E.164, and nothing else. `User.email`
survives as an optional contact column but authenticates nothing: there is no
email login path, and Google/Apple sign-in was removed along with the
`LinkedAccount` model (a second provider-anchored namespace has no role in a
phone-only product, and the verifier behind it had an unauthenticated-takeover
bug).

Every request field that carries a phone number is normalised at the DTO
boundary by `common/phone/phone.ts`: Arabic-Indic and Persian digits fold to
ASCII, `09…` / `00963…` / bare national forms expand to `+963…`, and anything
that cannot be a mobile number is rejected before it reaches a service. Two
spellings of the same number are therefore the same account.

### Signing in is a code, not a password

The primary journey is two calls and no password at all:

```
POST /auth/otp/login/start   { phone, client_nonce? }  -> { match_code, masked_destination, expires_at }
POST /auth/otp/login/verify  { phone, code, client_nonce? }
      -> { status: "authenticated",          user, tokens }
      |  { status: "registration_required",  phone, registration_ticket }
```

`start` answers **byte-identically** for a number with an account and one
without — same shape, same masked destination. It has to: the route is
unauthenticated by necessity, and any difference in the answer is a public
lookup for "is this woman on Ohara", which on this platform is a question with
consequences well past the account. The first moment the platform says anything
about whether the number is known is *after* the code is spent.

An unknown number comes back with a **registration ticket**: a short-lived
signed assertion that this number was just proved. `POST /auth/register`
requires it, and that ordering is the fix for a real hole — registration used to
mint an account for any number anybody typed, so one person could sit down and
claim every number in a contact list, permanently locking those women out of
signing up under their own.

`client_nonce` is the second half of the anti-relay defence that `match_code`
starts. The challenge stores its hash and demands it back at verification, so a
code recited over the phone to "Ohara support" cannot be spent from their handset.

### The password is optional, and it cannot admit a new device

Owner decision 1. `User.passwordHash` is null on a normal Ohara account;
`passwordSetAt` records when she opted in, so "never had one" and "had one,
removed it" stay distinguishable in a takeover timeline. Managed at
`POST` / `DELETE /auth/account/password`, both at AAL3.

`POST /auth/login` still exists, and a correct password on a handset the account
has never signed in from does **not** produce a session. It produces a code:

```
403 DEVICE_VERIFICATION_REQUIRED
{ code, message, details: { challenge: { match_code, masked_destination, ... } } }
```

That single rule is what makes offering a password defensible. The credential
most likely to be reused from a breached site, guessed or shoulder-surfed cannot
on its own move the account onto somebody else's phone — it only shortens the
journey on a handset that already completed a code. "Known device" means a
`DeviceKey` that is *this account's*, not revoked, and carrying `verifiedAt`,
which is set only by completing a challenge on the device itself.

Every pre-credential failure still answers `INVALID_CREDENTIALS`; account state
is disclosed only after the credential verifies. Seller approval is not a login
gate — an applicant signs in normally and sees her application status; approval
is enforced on the seller routes via `requireSellerVerified`.

One-time codes come from `crypto.randomInt`, are stored as peppered HMACs, and
are **never** returned in a response.

### Moving the account to another number is two-sided

```
POST   /auth/account/phone/start              { new_phone }        AAL3 + device proof
POST   /auth/account/phone/:id/verify-current { code }             -- the OUTGOING number
POST   /auth/account/phone/:id/confirm        { code }             -- the INCOMING number
GET    /auth/account/phone/pending
DELETE /auth/account/phone/:id
```

The number IS the account — login, recovery channel and second factor at once —
so changing it is a transfer, not a profile edit, and `PATCH /auth/account` no
longer accepts `phone` at all. The old flow took one code, on the *incoming*
number, which is precisely the proof a SIM swapper has. The outgoing number is
challenged **first**, because it is the half an attacker cannot answer and
asking it first means no code is ever sent to a number they control.

Completing it revokes every other session and freezes payouts for seven days.

### The last door: support-mediated recovery

For the one case nothing else reaches — the SIM is gone, no recovery code, no
authenticator.

```
POST /auth/recovery/cases            public, 3/hour   { claimed_phone, contact_phone, contact_code, ...evidence }
POST /auth/recovery/cases/:id/status public           { claim_secret }
GET  /auth/recovery/cases            bearer           -- cases open against MY account
POST /auth/recovery/cases/:id/cancel bearer           -- the owner stopping one
```

Owner decision 4: the evidence collected is **platform-held data only** — when
she joined, what her last order came to, what one of her devices is called.
There is no field for a selfie or an identity document, and there will not be:
that queue would be a liability whose worst case is not fraud, and the documents
answer the wrong question anyway (who is holding a phone today, not who opened
the account). Answers are stored as *what matched*, never as what she typed, so
a case file never becomes a second copy of her order history in a support tool.

Four controls carry the weight instead, and an attacker has to beat all four:

1. **Knowledge only the platform holds**, scored automatically and never
   disclosed — the claimant is told "submitted" and nothing more.
2. **Dual control** — two *distinct* staff accounts must approve.
3. **A 72-hour cool-off**, during which the number on file is notified and one
   tap from her kills the case.
4. **A 7-day payout freeze** afterwards.

Completion is driven by elapsed time in `AuthRetentionCron`, not by a staff
click, so no single person can carry a case all the way through. **Privileged
accounts are refused this path outright** — recovering an admin account through
a support queue is the highest-value attack against the platform.

### Staff view

```
GET    /admin/security/events                  security_forensics:read
GET    /admin/security/login-attempts          security_forensics:read
GET    /admin/security/users/:id/timeline      security_forensics:read
GET    /admin/security/users/:id/sessions      session:manage
DELETE /admin/security/users/:id/sessions      session:manage + AAL3
GET    /admin/security/recovery-cases          account_recovery:review
POST   /admin/security/recovery-cases/:id/approve   account_recovery:review + AAL3
POST   /admin/security/recovery-cases/:id/reject    account_recovery:review
```

The timeline merges security events, sign-in attempts, audit lines and the
challenges the platform sent her into one ordered story — merged rather than
four lists, because "code requested, delivered by SMS, sign-in from a new
device, all other sessions revoked, payout details changed" reads as a takeover
in sequence and as noise in four tables. It returns how the account was
*accessed*, never what was in it: no orders, no messages, no addresses.

### Retention

`AuthRetentionCron` owns two jobs. Every ten minutes it advances the
clock-driven transitions — sessions past their absolute lifetime, lapsed phone
changes and recovery cases, and hand-overs whose cool-off has run out. Nightly
it ages out the operational rows: proof replay guards (1h), step-up grants and
refresh tokens (30d), closed sessions and challenges (90d), sign-in attempts
(180d), routine audit/security telemetry (400d). Anything marked WARNING or
above is kept, because a takeover is often reported months later.

## Assurance ladder and the new-device cooldown

Not every action deserves the same proof, so routes declare what they need with
`@RequireStepUp(level, scope)`.

* **AAL2** — a fresh device proof on this request. Applied to delivery-address
  writes: on this platform the stored address is a woman's home, so writing one
  is not an ordinary profile edit.
* **AAL3** — a second factor consumed in the last ten minutes, plus the device
  proof. Applied to phone change, password change, device revocation,
  logout-others, seller-verification submission and OTP transport-route writes.
  Device revocation and logout-others are on this list because they are the
  intruder's best move as much as the owner's.

Elevation lasts **ten minutes** and is scoped: a code approved for an address
change cannot silently authorise a payout change. `POST /auth/step-up/request`
issues the challenge through the ordinary delivery chain, `POST
/auth/step-up/verify` consumes it and elevates the session, and every grant is
recorded in `step_up_grants`.

**The cooldown.** For the first 24 hours after a device is seen for the first
time, the AAL3 list is refused *outright* — `403 NEW_DEVICE_COOLDOWN`, and no
challenge clears it. That is not an oversight in the ladder, it is the point:
every second factor a consumer can present today arrives on her SIM, so if an
attacker holds the SIM they hold the second factor too and every rung is
transitively defeated by the one attack it exists to stop. A delay is the only
control that does not route back through the attacker's hand, and it works
because a swapper acts within minutes while a real owner can wait a day.

The 24 hours is a **hardcoded constant, deliberately not configurable** — at one
hour it stops working, and a config value will be shortened.

Signing in from a new device also notifies every other session with a one-tap
"sign out everywhere".

**Known limitation:** step-up is OTP-only today, so during the cooldown window
the ladder rests on the delay alone. TOTP and recovery codes are the next track
and slot into `StepUpMethod` without changing any caller.

On the client, `LocalAuthGate` re-authenticates the *person* — biometric or
device PIN — by default wherever the hardware exists, with a 15-minute
background grace. It is the only answer to the dominant real threat here:
somebody picking up an unlocked handset.

## Recovery codes and TOTP

Two second factors that do **not** arrive on the SIM. Without them the whole
assurance ladder is transitively defeated by a SIM swap, because every other
channel is a message to the same number.

**Recovery codes** — ten single-use codes, argon2id-hashed (they live for
months, unlike a six-digit OTP), shown once. Generating a set is AAL3, because
a fresh set silently invalidates the old one: an intruder who could regenerate
would lock the owner out of her own fallback while handing herself a new one.
`GET /auth/recovery/codes` returns counts only, never a code. Redemption is a
compare-and-set, so two concurrent uses of one code cannot both win.

Adoption will be low — people do not reliably keep ten codes on paper — and the
design says so: this is one leg of three, beside the support-mediated path and
the optional password, not the answer on its own.

**TOTP** (RFC 6238, verified against the RFC's own SHA-1 vectors) — 30s period,
±1 window, and a `lastUsedCounter` replay guard so a code seen over a shoulder
cannot be re-entered inside its own 30 seconds. The secret is AES-256-GCM
encrypted under `TOTP_ENC_KEY`: a shared secret must be recoverable to be
verified, so it is encrypted rather than hashed, and under its own key so a
database dump alone yields no working authenticators.

TOTP is **mandatory for the seven privileged roles**, and the argument is
availability rather than cryptography: it is the only factor with no network
anywhere in its path. If Meta, the SMS aggregator and the Syrian mobile network
are unreachable at once, that is exactly when operations staff are needed — and
exactly when every other factor is unavailable. The rule is enforced twice:
`AdminService.updateUser` refuses to grant a privileged role to an account with
no confirmed authenticator, and `PrivilegedMfaInvariant` re-checks at boot —
logging in development, refusing to start in production, because a rule checked
only at write time rots the first time somebody fixes a role in SQL.

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/auth/recovery/codes` | AAL3 | issue ten codes, once |
| GET  | `/auth/recovery/codes` | bearer | counts only |
| POST | `/auth/totp/enroll` | bearer | secret + `otpauth://` URI, once |
| POST | `/auth/totp/confirm` | bearer | prove the authenticator works |
| POST | `/auth/step-up/verify` | bearer | `method: otp \| totp \| recovery_code` |

## Device identity and sessions

A device is a **public key**, not a fingerprint. The app generates an Ed25519
keypair on first launch, registers the public half at `POST /auth/device-keys`,
and signs a short-lived proof for the requests that assert possession of the
handset. The old identity was SHA-256 over six client headers *including the IP
address* — forgeable by anyone who can set a header, and different after every
cell handover, which is why "trust this device" never stuck and why a revoked
device came back as a new one on the next network.

**The proof** is a compact JWS over `{jti, iat, htm, htu, ath}`, sent as
`X-Reem-Device-Proof`. `htm`/`htu` bind it to this method and URL, `ath` binds
it to the access token beside it, `iat` bounds it to ±60s, and `jti` is
recorded in `device_proof_jtis` so it cannot be used twice. Anything but
`alg: EdDSA` is rejected before the payload is parsed.

**Sessions run two clocks.** `idle_expires_at` slides forward on every
rotation; `absolute_expires_at` never moves — 90 days for shoppers and sellers,
12 hours for the seven privileged roles. Without the second clock a chain
rotated weekly lives forever and there is no re-authentication checkpoint at
all.

**Rotation is a compare-and-set.** `updateMany` filtered on
`usedAt: null, revokedAt: null`; `count === 0` means the token was already
spent, which is reuse and revokes the session. The previous read-then-write let
two concurrent presentations of one token both pass the reuse check and both
mint a chain — silently disabling the one detection control the design rests
on. Rotation also re-checks `disabledAt`, so a suspended account stops renewing.

A refresh token issued to a device can only be rotated by a caller who can sign
with that device's key, which makes an exfiltrated token an inert string.

`POST /auth/devices/:id/trust` is **gone**: it conferred trust on nothing more
than a live session and a device id. Trust is earned by completing an OTP
challenge on the device.

Device keys are software-backed today (secure storage, not Keystore/Secure
Enclave) and record `hardware_backed` honestly. The wire format is identical
either way, so hardware is a later value change rather than a schema change —
a deliberate trade against platform-channel regressions on the Transsion,
Xiaomi and no-GMS handsets common in the market.

## OTP delivery

Getting six digits onto a handset in Syria is a subsystem, not a function call
(`src/modules/auth/otp/`).

Creating a challenge writes an **outbox** row in the same transaction, so a
code can never exist without being queued. A 5-second cron drains it with
`FOR UPDATE SKIP LOCKED` and dispatches through a **priority chain read from
`otp_transport_routes`** — WhatsApp Cloud → local Syrian SMS aggregator →
voice → ops console. The chain is a table so operations can flip the primary
channel during a Meta policy action with one `PATCH`, no deploy.

Each attempt writes a `challenge_deliveries` row, which is where success rate,
time-to-handset and cost per channel come from. Failover fires on two signals:
an explicit failure receipt, and **25 seconds of silence** after a provider
accepted the message — the dominant Syrian failure mode is "accepted, never
delivered" (no data bundle, blocked template, carrier throttling). Escalation
carries the **same code** to the next transport, so she is never told to start
over; that is why the outbox seals the plaintext under `OTP_DELIVERY_KEY` and
shreds it the moment the challenge is used, delivered or expired.

Every response carries a two-digit `match_code` also printed in the message.
It is the defence against "this is Ohara support, read me your code": a code
recited to her over the phone will not match the digits on her screen.

Per-transport `daily_budget_micros` trips a circuit breaker that falls through
to the *cheaper* channel — cost degrades before access, which is the only hard
cap on the one line item that can breach the ops budget.

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET   | `/admin/auth/delivery/report` | admin | success rate, median time-to-delivery, cost per transport |
| PATCH | `/admin/auth/delivery/routes/:transport` | admin | priority, enable, budget, reset breaker — writes a CRITICAL security event |
| GET   | `/admin/auth/delivery/pending-challenges` | admin | closed-beta read-out; every reveal is recorded |
| GET/POST | `/webhooks/whatsapp` | public + HMAC | Meta delivery receipts |

**Closed beta before a carrier contract:** `AUTH_OPS_TRANSPORT_ENABLED=true`
makes the last link in the chain an admin screen a team member reads codes
from. It exposes plaintext codes to staff, does not scale past a few dozen
testers, and the environment validator refuses it when `NODE_ENV=production`.

## Auth flow

1. `POST /auth/otp/login/start` `{ phone }` → a code, and a `match_code` she is
   meant to compare against the message.
2. `POST /auth/otp/login/verify` `{ phone, code }` → either `{ status: "authenticated", user, tokens }`
   or `{ status: "registration_required", registration_ticket }`.
3. If registration is required: `POST /auth/register`
   `{ first_name, last_name, phone, registration_ticket, country, city, declared_female, password? }` → `{ user, tokens }`
   (role ∈ customer|seller; admin cannot self-register. `declared_female` must be `true` — Q43/Q138 P1, the women-only rule is a self-declaration and this is where it is made. `password` is optional and the default is not to have one.)
4. Send `Authorization: Bearer <access_token>` on protected routes.
5. On 401, `POST /auth/refresh-token` `{ refresh_token }` → new `{ user, tokens }` (old refresh token is rotated/invalidated).
6. `POST /auth/logout` `{ refresh_token }` revokes the refresh token server-side.

`POST /auth/login` `{ phone, password }` is the optional side door for a woman
who set a password, and refuses with `DEVICE_VERIFICATION_REQUIRED` plus a
challenge on any handset the account has not used before.

`tokens = { access_token, refresh_token }`. Access TTL 15m, refresh TTL 7d (configurable).

## Endpoints

### Auth
| Method | Path | Auth | Body |
|---|---|---|---|
| POST | `/auth/otp/login/start` | public | `phone, client_nonce?` |
| POST | `/auth/otp/login/verify` | public | `phone, code, client_nonce?` |
| POST | `/auth/register` | public | `first_name, last_name, phone, registration_ticket, country, city, declared_female, password?, role?` |
| POST | `/auth/login` | public | `phone, password` — optional; refuses an unenrolled device |
| POST | `/auth/refresh-token` | public | `refresh_token` |
| POST | `/auth/logout` | public | `refresh_token` |
| POST | `/auth/forgot-password` | public | `phone` |
| GET  | `/auth/me` | bearer | — |
| GET  | `/auth/account` | bearer | profile, permissions, full security state, open recovery cases |
| POST | `/auth/account/password` | AAL3 | `new_password, current_password?` |
| DELETE | `/auth/account/password` | AAL3 | — |
| POST | `/auth/account/phone/start` | AAL3 | `new_phone` |
| POST | `/auth/account/phone/:id/verify-current` | AAL3 | `code` |
| POST | `/auth/account/phone/:id/confirm` | AAL3 | `code` |
| POST | `/auth/recovery/cases` | public | recovery claim, 3/hour |
| POST | `/auth/recovery/cases/:id/cancel` | bearer | the owner stopping a hand-over |

### Users & Profile
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET   | `/users/me` | bearer | own profile + stats |
| PATCH | `/users/me` | bearer | `name?, bio?, image_url?, location?` |
| GET   | `/users/:id` | bearer | profile + `is_following`, `is_me`, stats, `seller_stats` |
| GET   | `/users/:id/followers` | bearer | list of users |
| GET   | `/users/:id/following` | bearer | list of users |
| POST  | `/users/:id/follow` | bearer | `{ is_following, followers_count }` |
| DELETE| `/users/:id/follow` | bearer | `{ is_following, followers_count }` |

### Other modules
`products` (public browse via `@OptionalAuth`: `/`, `/home`, `/trending`, `/new-arrivals`,
`/featured`, `/most-loved`, `/top-rated`, `/search`, `/category/:c[...]`, `/:id`; authed mutations
`/:id/views|orders|stock/reduce`), `posts` (`/feed`, create, `/:id/like`), `stories`, `orders`,
`favorites`, `chats`, settings (`addresses`, `coupons`, `rewards`, `notifications`,
`payment-methods`), `admin/*` (ADMIN only).

## Conventions

- **JSON is snake_case** in & out. IDs are UUIDs.
- **Errors:** `{ statusCode, message, error }` (message may be a string array for validation).
- **No global prefix** by default (`API_PREFIX=""`) so paths match the Flutter `ApiEndpoints`.

## Scripts

| Command | Description |
|---|---|
| `npm run dev` | Watch mode |
| `npm run build` | Compile (`nest build`) |
| `npm run start:prod` | Run `dist/main.js` |
| `npm run db:push` | Sync schema to DB |
| `npm run db:migrate` | Create a migration |
| `npm run db:seed` | **Deletes every row**, then seeds reference + demo data. Refused when `NODE_ENV=production` unless `ALLOW_DESTRUCTIVE_SEED=true` |
| `npm run db:setup` | Migrate and generate the client |
| `npm run db:setup:demo` | Migrate, generate, then **wipe and seed** |
| `npm run db:studio` | Prisma Studio |

## Production checklist

- Four **distinct** keyring secrets, 32+ random chars each: `JWT_ACCESS_SECRET`,
  `JWT_REFRESH_SECRET`, `OTP_PEPPER`, `GUEST_TOKEN_PEPPER`. The env validator
  refuses to boot if any is missing, short, or shared with another.
- `NODE_ENV=production` (now required — it is no longer optional, because two
  fail-open branches used to key off it being unset), restrict `CORS_ORIGINS`
- `TRUST_PROXY` set when a reverse proxy is in front, or IP rate limiting sees
  only the proxy and the whole platform shares one bucket
- `OTP_DEV_ECHO` must be absent; boot fails if it is `true` in production
- Rate-limit state is in-process: it is correct for a single instance, and a
  second one needs shared storage before the limits mean anything
- `npm run db:migrate:deploy` for migrations
- Terminate TLS at a load balancer / reverse proxy
- **Contract an OTP transport before any real user signs up.** The chain is
  built and drains correctly, but every provider slot is empty: with nothing
  configured the only link left is the ops console. Sign the local SMS
  aggregator first — its contract cannot be refused for sanctions reasons and
  it reaches a handset with mobile data off — then promote WhatsApp with one
  `PATCH` once its Arabic template is approved.
- Roadmap: Redis (sessions, rate-limit store, feed cache), object storage (media uploads)
