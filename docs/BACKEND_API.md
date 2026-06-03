# Node.js Backend API Contract

Base URL: `/api/v1` (configurable via `AppEnv.baseUrl`)

All JSON fields use **snake_case**. Authenticated routes expect:

```
Authorization: Bearer <access_token>
```

## Auth (`/auth`)

| Method | Path | Body | Response |
|--------|------|------|----------|
| POST | `/auth/login` | `{ email, password }` | `{ user, tokens: { access_token, refresh_token } }` |
| POST | `/auth/register` | `{ name, email, password }` | same as login |
| POST | `/auth/refresh-token` | `{ refresh_token }` | same as login |
| GET | `/auth/me` | — | `user` object or `{ user: {...} }` |
| POST | `/auth/forgot-password` | `{ email }` | `{ message }` |

## Users

| Method | Path | Notes |
|--------|------|-------|
| GET/PATCH | `/users/me` | Profile read/update |

## Social

| Method | Path | Notes |
|--------|------|-------|
| GET | `/posts/feed` | List of posts (author, product embedded) |
| POST | `/posts` | Create post |
| POST | `/posts/:id/like` | Toggle like |
| GET | `/stories` | Active stories |

## Products

| Method | Path | Notes |
|--------|------|-------|
| GET | `/products` | Paginated list |
| GET | `/products/trending` | Trending products |
| GET | `/products/:id` | Product detail |

## Commerce

| Method | Path | Notes |
|--------|------|-------|
| GET | `/orders` | User orders |
| GET/POST/DELETE | `/favorites` | Wishlist |

## Chat

| Method | Path | Notes |
|--------|------|-------|
| GET | `/chats` | Conversation threads |
| GET | `/chats/:id/messages` | Messages |
| POST | `/chats/:id/messages` | `{ content, type? }` |

## Settings

| Method | Path | Notes |
|--------|------|-------|
| GET/POST | `/addresses` | Shipping addresses |
| GET | `/coupons`, `/rewards`, `/notifications` | |
| GET/POST | `/payment-methods` | |

## Admin (role: admin)

| Method | Path | Response shape |
|--------|------|----------------|
| GET | `/admin/stats` | `{ total_sales, total_orders, active_users, conversion_rate, ..._trend }` |
| GET | `/admin/orders` | Order list |
| GET | `/admin/products` | Product list |
| GET | `/admin/users` | User list |
| GET | `/admin/analytics` | Analytics series |

## Error format

```json
{
  "message": "Human-readable error",
  "error": "Optional code"
}
```

HTTP status: `401` unauthorized, `422` validation, `404` not found, `5xx` server.

## Suggested Node.js layout

```
src/
  modules/
    auth/
    users/
    posts/
    stories/
    products/
    orders/
    favorites/
    chats/
    addresses/
    admin/
  middleware/
    auth.middleware.ts
    error.middleware.ts
  app.ts
```

Use JWT access + refresh tokens; store refresh tokens securely; validate payloads with Zod or class-validator.

---

## Implemented server

A full reference implementation lives in [`backend/`](../backend/README.md).

```bash
cd backend && docker compose up -d && npm install && npm run db:push && npm run db:seed && npm run dev
```

Demo login: `sara@reem.shop` / `Password123!`
