# Reem API (Node.js)

Production-ready REST API for the **Reem Shop** Flutter application.

## Stack

- **Node.js 20+** · **TypeScript** · **Express**
- **PostgreSQL** · **Prisma ORM**
- **JWT** access + refresh tokens · **bcrypt** passwords
- **Zod** validation · **Helmet** · **CORS** · **Rate limiting** · **Pino** logging

## Quick start

### 1. Install & configure

```bash
npm install
cp .env.example .env   # if .env does not exist
```

### 2. Database setup (SQLite — no Docker required)

```bash
npm run db:push
npm run db:seed
```

Creates `prisma/dev.db` with demo users, products, posts, chats, and more.

### 3. Run API

```bash
npm run dev
```

Server: **http://localhost:3000/api/v1**

Health check: `GET http://localhost:3000/api/v1/health`

## Demo accounts (after seed)

| Role  | Email            | Password      |
|-------|------------------|---------------|
| User  | sara@reem.shop   | Password123!  |
| Admin | admin@reem.shop  | Admin123!     |

## Flutter connection

Default app URL matches this server:

```
http://localhost:3000/api/v1
```

**Android emulator** — use:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

**Physical device** — use your machine LAN IP (same Wi‑Fi):

**PostgreSQL (optional, production-like):** start Docker (`docker compose up -d`), set `DATABASE_URL` in `.env` to the Postgres URL from `.env.example`, change `provider` in `prisma/schema.prisma` to `postgresql`, then `npm run db:push && npm run db:seed`.

**Physical device** — use your machine LAN IP:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3000/api/v1
```

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Development with hot reload |
| `npm run build` | Compile TypeScript |
| `npm start` | Run production build |
| `npm run db:push` | Sync Prisma schema to DB |
| `npm run db:migrate` | Create migration (production) |
| `npm run db:seed` | Seed demo data |
| `npm run db:studio` | Prisma Studio GUI |
| `npm run lint` | Typecheck |

## API modules

- `auth` — register, login, refresh, me, forgot password
- `users` — profile GET/PATCH
- `posts` — feed, create, like
- `stories` — list, create (24h expiry)
- `products` — list, trending, detail
- `orders` — user orders
- `favorites` — wishlist
- `chats` — threads, messages
- `addresses`, `coupons`, `rewards`, `notifications`, `payment-methods`
- `admin` — stats, orders, products, users, analytics (admin role)

Full contract: [../docs/BACKEND_API.md](../docs/BACKEND_API.md)

## Production checklist

- Set strong `JWT_*_SECRET` values (32+ chars)
- Use `npm run db:migrate:deploy` for migrations
- Set `NODE_ENV=production`
- Restrict `CORS_ORIGINS` to your app domains
- Put API behind HTTPS (nginx / cloud load balancer)
- Configure real email for forgot-password (see `auth.service.ts`)
