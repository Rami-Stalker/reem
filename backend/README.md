# Reem API — NestJS

Production-grade REST API for the **Reem** women-focused social-commerce platform.

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
docker compose up -d          # PostgreSQL 16 on localhost:5432
npm run db:push               # create schema  (or: npm run db:migrate)
npm run db:seed               # demo users, products, posts, follows, ...
npm run dev                   # http://localhost:5432
```

Health: `GET http://localhost:5432/health`

## Demo accounts (after seed) — phone / password

| Role     | Phone           | Password      |
|----------|-----------------|---------------|
| Admin    | `+966500000001` | `Admin123!`   |
| Seller   | `+966500000002` | `Seller123!`  |
| Customer | `+966500000005` | `Password123!`|

## Auth flow

1. `POST /auth/register` `{ name, phone, password, role? }` → `{ user, tokens }` (role ∈ customer|seller; admin cannot self-register)
2. `POST /auth/login` `{ phone, password }` → `{ user, tokens }`
3. Send `Authorization: Bearer <access_token>` on protected routes.
4. On 401, `POST /auth/refresh-token` `{ refresh_token }` → new `{ user, tokens }` (old refresh token is rotated/invalidated).
5. `POST /auth/logout` `{ refresh_token }` revokes the refresh token server-side.

`tokens = { access_token, refresh_token }`. Access TTL 15m, refresh TTL 7d (configurable).

## Endpoints

### Auth
| Method | Path | Auth | Body |
|---|---|---|---|
| POST | `/auth/register` | public | `name, phone, password, role?` |
| POST | `/auth/login` | public | `phone, password` |
| POST | `/auth/refresh-token` | public | `refresh_token` |
| POST | `/auth/logout` | public | `refresh_token` |
| POST | `/auth/forgot-password` | public | `phone` |
| GET  | `/auth/me` | bearer | — |

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
| `npm run db:seed` | Seed demo data |
| `npm run db:studio` | Prisma Studio |

## Production checklist

- Strong `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` (32+ random chars)
- `NODE_ENV=production`, restrict `CORS_ORIGINS`
- `npm run db:migrate:deploy` for migrations
- Terminate TLS at a load balancer / reverse proxy
- Wire a real SMS provider for phone OTP / password reset (see `auth.service.ts`)
- Roadmap: Redis (sessions, rate-limit store, feed cache), object storage (media uploads)
