# Database — local setup

The Ohara backend runs on PostgreSQL 18 with Prisma. This document covers how the
database is provisioned, how DBeaver connects to it, and the two things about
this particular machine that are worth knowing.

---

## What is installed

A native **PostgreSQL 18** server, running as the Windows service
`postgresql-x64-18`:

| | |
| --- | --- |
| Binaries | `C:\Program Files\PostgreSQL\18\bin` |
| Data directory | `C:\Program Files\PostgreSQL\18\data` |
| Port | 5432 |
| Auth | `scram-sha-256` for all local and loopback connections |
| Starts | automatically with Windows |

`psql` is **not on PATH**. Either add `C:\Program Files\PostgreSQL\18\bin` to
PATH, or run `C:\Program Files\PostgreSQL\18\pg_env.bat` first, or call the
binary by full path.

DBeaver is a *client* — it browses and queries this server, it does not host one.

> The installer re-initialised the data directory on 2026-08-18, so the cluster
> created back in June (with the earlier `reem_db`) is gone. Nothing of value was
> lost: the schema it held is the pre-redesign one, and the seed rebuilds
> everything.

---

## One-time provisioning

The installer creates only the `postgres` superuser. The application role and
database are created by a script, run once:

```bash
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -f "C:\dev\reem\backend\prisma\provision.sql"
```

Or paste `backend/prisma/provision.sql` into a DBeaver SQL editor while
connected as `postgres`.

It creates `reem_user` (password `12345678`, with `CREATEDB`) and the `reem_db`
database owned by that role, then grants it ownership of the `public` schema.

Nothing after this point needs superuser rights.

### Why `CREATEDB` matters

`prisma migrate dev` creates a temporary *shadow database* to diff the schema
against. Without `CREATEDB` on the application role it fails with P3014, and
every schema change has to go through the `prisma migrate diff --script` +
`migrate deploy` workaround. This project hit exactly that before, so the role is
provisioned with `CREATEDB` from the start.

### Why the `public` grant matters

On PostgreSQL 15+ the `public` schema is owned by the bootstrap superuser and is
no longer world-writable. Without an explicit grant, the first migration fails
with `permission denied for schema public`.

---

## Everyday commands

All from `backend/`:

```bash
npm run db:setup
```

That applies migrations, regenerates the Prisma client and seeds demo data.

| Command | What it does |
| --- | --- |
| `npm run db:provision` | one-time role + database creation (needs `postgres`) |
| `npm run db:status` | which migrations are applied |
| `npm run db:deploy` | apply pending migrations |
| `npm run db:migrate` | create a new migration from schema changes |
| `npm run db:reset` | drop everything, re-migrate, re-seed |
| `npm run db:seed` | re-run the seed only |
| `npm run db:studio` | Prisma Studio |

---

## Connecting DBeaver

A connection named **Ohara — local** is already defined in the DBeaver
workspace and points at `localhost:5432/reem_db` as `reem_user`; it prompts for
the password on first connect. To create one by hand —
`Database → New Database Connection → PostgreSQL`:

| Field | Value |
| --- | --- |
| Host | `localhost` |
| Port | `5432` |
| Database | `reem_db` |
| Username | `reem_user` |
| Password | `12345678` |
| Show all databases | off |

To administer the server itself (create roles, inspect other databases), connect
a second time as `postgres` with the password set during installation.

---

## Arabic collation

`reem_db` is created with an ICU locale:

```sql
CREATE DATABASE reem_db ... LOCALE_PROVIDER icu ICU_LOCALE 'ar-SY'
```

The Windows installer defaults the *cluster* to `English_United States.1256`, so
the database overrides it. Without the override, `ORDER BY title` sorts Arabic by
raw byte value and categories come back as أحذية, إكسسوارات, ملابس in an order no
Arabic reader would call alphabetical.

This can only be set when the database is **created**. Changing it later means
dropping and recreating `reem_db`.

---

## The container is a fallback, not the default

`backend/docker-compose.yml` defines the same database as a container on port
**5433**, so it can run alongside the native server. It is useful for a
clean-room cluster that needs no installer and no superuser — a fresh machine, CI,
or reproducing a bug against an empty database. To use it, point `DATABASE_URL`
at 5433 and run `docker compose up -d --wait`.

Docker Desktop on this machine needed repair before it would start at all: it
crash-looped on stale AF_UNIX socket files left from an earlier run
(`%LOCALAPPDATA%\Docker\run\dockerInference`,
`%LOCALAPPDATA%\docker-secrets-engine\engine.sock`). They are reparse points that
Windows refuses to delete, so the fix is to stop Docker and **rename their parent
directories aside** — Docker recreates them. `EnableDockerAI` was also set to
`false` in `%APPDATA%\Docker\settings-store.json` (backup:
`settings-store.json.bak-reem`), because the Inference manager was the first
service to trip over the stale socket.

---

## Schema notes

- **Money** is `Decimal(18,4)` paired with an explicit `Currency` column on every
  row that holds an amount — no `Float`, and no implicit currency anywhere. See
  `src/common/money/money.ts` for why arithmetic must never touch the raw column
  values directly.
- **Migrations** live in `prisma/migrations/`. The latest,
  `20260818170000_catalog_offers_suborders_money`, is destructive: it drops
  `products.seller_id` and `orders.total` and re-parents `order_items` onto
  `seller_orders`. It is written for a pre-launch database — reset and reseed
  rather than applying it over rows that matter.
- **Appointments** (`20260917120000_salons_and_appointments`) add eight tables
  for «الصالونات والجمال». They are additive — nothing existing is dropped or
  altered — so the migration is safe to apply over live rows. No unique index
  protects a booked slot, and cannot: durations vary and a salon may have
  several chairs, so the rule is a `FOR UPDATE` overlap count in
  `appointments.service.ts`. Read [SALONS.md](SALONS.md) before touching it.
- **Occasions** (`20261023120000_occasions`) add one table for «مناسباتي». It
  is additive and safe over live rows. An occasion links a `closet_looks` row
  and an `appointments` row with `ON DELETE SET NULL`, and its checklist is
  derived from those links rather than stored. See [OCCASIONS.md](OCCASIONS.md).
- **Fit reviews** (`20261024090000_fit_reviews`) add `fit_profiles` and five
  nullable columns on `product_reviews` (fit, size bought, height band, usual
  size, photos) for «تقييمات من بمقاسي». Height band and usual size are
  stored for matching only and are never served. Additive; old reviews simply have
  none of them. See [FIT_REVIEWS.md](FIT_REVIEWS.md).
- **Customer feedback** (`20261023130000_customer_feedback`) creates the
  `customer_feedback` table. The model had been in `schema.prisma` without a
  migration, so no deployed database had it. The same migration renames one
  index Postgres had shortened to 63 letters. CI now runs `prisma migrate diff`
  after applying the migrations and fails if the schema and the migrations
  disagree, which `migrate status` alone never checked.
- **Seeding** is wired through `prisma.config.ts`, so `prisma migrate reset`
  reseeds automatically. That config file also has to `import 'dotenv/config'`
  explicitly, because the presence of a Prisma config file disables the CLI's
  implicit `.env` loading.

---

## The demo dataset

`npm run db:seed` runs in two passes. `prisma/seed.ts` writes the **reference
data** the platform cannot start without — permissions and roles, content-type
definitions, the three-level category tree, size charts, shipping zones, the
FX rate, commission rules and the named demo accounts. Then `prisma/demo/`
layers a **showcase dataset** on top of it, sized so every screen in the app
has something real to render.

Roughly what lands in the database:

| Area | What is there |
| --- | --- |
| People | 12 boutiques (BASIC/VERIFIED/PREMIUM, with verification files, reputation, badges), 12 shoppers, 40 community accounts |
| Catalog | ~165 canonical products over 27 leaf categories, 3 photos each, size/shade/volume variants, ~310 seller offers — most products carry competing offers from two or three boutiques, a few priced in USD |
| Social | ~80 posts (product, multi-product and content-only), ~1900 likes, comments, saves, 24 live stories with views and reactions, rich `commerce_contents` with product tags |
| Commerce | ~65 orders covering **all 19 sub-order states**, per-seller sub-orders, payments and transactions, shipments with tracking events, returns, disputes, courier cash settlements |
| Money | Commission ledger, weekly seller payouts, double-entry financial ledger, points, cashback, coupons and redemptions, membership tiers |
| Ops | ~4200 analytics events shaped as real funnels, AI interaction logs, support tickets, moderation queue, audit and security trail, notification campaign with deliveries |

Three properties are worth knowing, because they are what make the data usable
rather than merely present:

- **It is deterministic.** Every random choice goes through the seeded
  generator in `prisma/demo/rng.ts`, so two runs produce the same catalog,
  prices and order history. Screenshots and QA scripts do not drift.
- **Counters equal rows.** `prisma/demo/reconcile.ts` recomputes
  `likes_count`, `rating`, `orders_count`, `followers_count` and friends from
  the rows that were actually written. Nothing is inflated — that is why the
  40 community accounts exist. (`views_count` is the exception: the schema has
  no per-view table, so that column is the source of truth, not a cache.)
- **Images come from one factory.** `prisma/demo/media.ts` builds every URL,
  at the 4:5 ratio the content policy mandates. Swapping the host for the
  project's own object storage later is one edit.

`SEED_DEMO=false npm run db:seed` stops after the reference data — the shape
CI and the contract fixtures want.

Demo accounts created by the seed:

| Role | Phone | Password |
| --- | --- | --- |
| Admin | `+966500000001` | `Admin123!` |
| Seller | `+966500000002` | `Seller123!` |
| Seller | `+963931000101` … `+963931000109` | `Seller123!` |
| Customer | `+966500000005` | `Password123!` |
| Customer | `+963932000201` … `+963932000211` | `Password123!` |

The community accounts (`reem_001` …) have no password by design: they exist to
give engagement counters something real to count, not to be logged into.

## Guards on the money tables

`LedgerService` enforces the ledger's rules on every write it makes. Since
migration `20261022090000_financial_integrity_guards` the database enforces
them too, so a hand-run fix or a script that bypasses the service fails where
it is made instead of surfacing in the nightly reconciliation:

- **Every journal entry balances**, per currency. A deferred constraint
  trigger checks each entry when its transaction commits.
- **Journal line amounts are positive** (`CHECK amount > 0`).
- **The ledger is append-only.** `journal_lines` cannot be updated or
  deleted, and a `journal_entries` row cannot be deleted or have its type,
  reference or date changed. Corrections are reversals.
- **A sale belongs to at most one payout.** A trigger on
  `seller_payout_ledgers` refuses a second link to the same commission row.

Deliberate maintenance — a redenomination, or the seed emptying its tables —
opts out for one transaction only:

```sql
SELECT set_config('reem.ledger_maintenance', 'on', true);
```
