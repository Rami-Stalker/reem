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
| GET | `/content/:id` | One piece — post, reel or story. `@OptionalAuth`; what a shared link opens. Declared last among the GETs on that controller, since `:id` would otherwise shadow `feed`, `reels`, `stories`, `saved` and `muted`. |

## Shareable links

HTML rather than JSON, and unauthenticated. Full account in
[SHARE_LINKS.md](SHARE_LINKS.md).

| Method | Path | Notes |
|--------|------|-------|
| GET | `/product/:id` | Product landing page, with Open Graph tags |
| GET | `/p/:id` | Post, reel or story |
| GET | `/user/:id`, `/u/:id` | Profile |
| GET | `/user/:id/products` | Storefront |
| GET | `/collection/:key` | A shelf of the catalogue |
| GET | `/rooms/join/:slug` | Room invite. Distinct from `POST /rooms/join/:slug`, which admits her |
| GET | `/invite/:code` | Referral. Web only — the app deliberately does not claim it |
| GET | `/` | The bare origin, which used to answer a JSON 404 |
| GET | `/.well-known/assetlinks.json` | Android App Links association |
| GET | `/.well-known/apple-app-site-association` | iOS Universal Links association |

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
| GET | `/chats` | Conversation threads (`?q=` searches names and messages) |
| POST | `/chats` | Open or reopen a thread: `{ product_id, seller_id? }`, `{ order_id }` or `{ participant_id }` |
| GET | `/chats/:id` | One thread's header, with its unread count |
| GET | `/chats/:id/messages` | Newest page, oldest first. `?before=<sent_at>&limit=` pages back |
| POST | `/chats/:id/messages` | `{ content, kind?, client_id?, attachments? }` — a repeated `client_id` returns the stored message instead of a duplicate |
| PATCH | `/chats/:id/read` | `{ message_id? }` — read up to that message (or the end); never moves backwards |
| POST/DELETE | `/chats/blocks/:userId` | Block / unblock |
| POST | `/chats/:id/reports` | Report the other participant |

The socket at `/ws/chats` (bearer token as the `reem.auth.bearer`
subprotocol) pushes `message.created` (with `is_mine` answered per
recipient), `messages.delivered` (`message_ids`), `messages.read`
(`user_id`, `up_to`), `typing` and `presence.changed`. A message is
delivered the moment the recipient's open socket receives it. Errors carry
`source_event` and the `client_id` of the send that failed.

## Salons and appointments (`/salons`, `/appointments`)

«الصالونات والجمال». The directory and a salon's page are public — a shared
salon link has to open for somebody who has not signed in. Everything else is
authenticated, and the owner's routes demand `salon:manage`.

Availability is **never** computed by a client: `/salons/:id/availability`
returns the free start times and a booking sends one of those instants back
untouched. See [SALONS.md](SALONS.md) for the booking invariant.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/salons` | Directory. `q`, `governorate`, `city`, `category`, `min_price`, `max_price`, `min_rating`, `home_service`, `sort` |
| GET | `/salons/categories` | Service categories with live counts |
| GET | `/salons/areas` | Localities that actually have salons |
| GET | `/salons/mine` | The caller's own salon, or `null` |
| GET | `/salons/:id` | By id **or slug** |
| GET | `/salons/:id/reviews` | Paginated |
| GET | `/salons/:id/availability` | `service_id`, `date` (`YYYY-MM-DD`) → free slots |
| GET | `/salons/:id/open-days` | `service_id`, `days` → slot counts per day |
| POST | `/salons/:id/appointments` | `{ service_id, starts_at, at_home?, address_id?, note? }` |
| PUT | `/salons` | Upsert the caller's salon. `status` moves between `DRAFT` and `ACTIVE` only |
| POST | `/salons/services` | Add a service |
| PATCH | `/salons/services/:serviceId` | Edit one |
| DELETE | `/salons/services/:serviceId` | Soft-close it — never deleted, because appointments reference it |
| PUT | `/salons/hours` | Replaces the whole week at once |
| POST/DELETE | `/salons/closures[/:date]` | Single closed dates |
| GET | `/salons/:id/queue` | The owner's queue. `filter` = `pending` / `upcoming` / `past` |
| POST | `/salons/reviews/:reviewId/reply` | The salon's answer to a review |
| GET | `/appointments` | Hers. `filter` = `upcoming` / `past` |
| GET | `/appointments/:id` | Either side; the salon's copy carries the customer block |
| POST | `/appointments/:id/cancel` | `{ reason? }`. Late cancellation is recorded, not refused |
| POST | `/appointments/:id/review` | `{ rating, body? }`, once, after `COMPLETED` |
| POST | `/appointments/:id/confirm` | Salon only |
| POST | `/appointments/:id/complete` | Salon only |
| POST | `/appointments/:id/no-show` | Salon only |

Every appointment payload carries `can_cancel` and `can_review`, decided by the
server, so a client can never offer a button the API would refuse.

## Fit reviews (`/fit-profile`, `/reputation/products/:id/…`)

«تقييمات من بمقاسي».

| Method | Path | Notes |
|--------|------|-------|
| GET | `/fit-profile` | Hers alone, with the sizes the picker offers |
| PUT | `/fit-profile` | `{ height_cm?, usual_size?, share_on_reviews? }`; `null` clears |
| GET | `/reputation/products/:id/reviews` | `filter` = `near_me` / `photos` (optional) |
| GET | `/reputation/products/:id/fit` | Fit tally overall and for women her size, suggested size, photo count |

`POST /reputation/products/:id/reviews` also takes `fit`, `photo_urls` (≤ 4,
her own `review` uploads) and `share_fit`. See [FIT_REVIEWS.md](FIT_REVIEWS.md).

## Occasions (`/occasions`)

«مناسباتي». Every route is authenticated and scoped to the caller.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/occasions` | `scope` = `upcoming` (default) / `past` |
| GET | `/occasions/:id` | Includes `repeats` — where the same people saw this outfit |
| POST | `/occasions` | `{ title, kind, date, starts_at_time?, location?, circle?, note?, look_id?, appointment_id?, reminders_enabled? }` |
| PATCH | `/occasions/:id` | Any of the above; `null` clears or unlinks |
| PUT | `/occasions/:id/steps/:key` | `{ done }` — only `gift` can be ticked by hand |
| DELETE | `/occasions/:id` | |

`steps`, `progress`, `next_step` and `days_left` are the server's. See
[OCCASIONS.md](OCCASIONS.md).

## Ohara AI Stylist (`/ai/stylist`)

The conversational shopping assistant. Every route is authenticated: a stylist
thread records what someone told an assistant about her body, her budget and
her occasions, and that is not a thing to hang off an anonymous session.

The pipeline behind these routes is fixed — understand, retrieve, rank,
assemble, persist, phrase — and **phrasing comes last, after the products are
already chosen and written down**. A language model, when one is configured at
all, reads sentences and writes sentences; it never selects a product, a price
or a stock level. With `AI_STYLIST_PROVIDER` unset the whole feature runs
deterministically, which is also the mode the tests run in.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/ai/stylist/bootstrap` | Opening prompts, recent threads, stored preferences, and the closed vocabularies the client's chips are drawn from |
| GET | `/ai/stylist/conversations` | Her active threads |
| POST | `/ai/stylist/conversations` | `{ title?, message? }` — a message opens and answers in one round trip |
| GET | `/ai/stylist/conversations/:id` | Transcript, with each turn's cards and look attached to the turn that produced them |
| DELETE | `/ai/stylist/conversations/:id` | Archives |
| POST | `/ai/stylist/conversations/:id/messages` | `{ content, modality? }` → the turn. Throttled to 20/min |
| POST | `/ai/stylist/outfits` | Builds a look from a brief posted as controls rather than typed |
| GET | `/ai/stylist/outfits` | `?status=SUGGESTED\|SAVED\|DISMISSED` |
| GET | `/ai/stylist/outfits/:id` | One look |
| PATCH | `/ai/stylist/outfits/:id` | `{ status }` — saving a look |
| GET | `/ai/stylist/recommendations` | Her card history |
| POST | `/ai/stylist/recommendations/:id/feedback` | `{ feedback }` — `LIKED`, `SAVED`, `DISMISSED`, `ADDED_TO_CART`, `PURCHASED` |
| GET | `/ai/stylist/preferences` | Stated taste plus what her behaviour says |
| PATCH | `/ai/stylist/preferences` | Partial: modesty, personas, colours, sizes, budget band |
| POST | `/ai/stylist/preferences/refresh` | Recomputes the behaviour-derived half |

### A turn

`POST /ai/stylist/conversations/:id/messages` answers with the exchange, the
cards, and the brief it was answered against:

```jsonc
{
  "conversation": { "id": "…", "brief": { … } },
  "user_message": { "role": "USER", "content": "بدي فستان سهرة بميزانية 900 ألف" },
  "message": {
    "role": "ASSISTANT",
    "content": "لقيتلك 6 خيارات فستان بتناسب سهرة، كلها متوفرة حاليًا. …",
    "engine": "reem-stylist-rules-v1",   // or the model id, when one answered
    "recommendations": [
      {
        "id": "…",
        "product": { … },                // the ordinary catalogue product shape
        "reason": "اخترتلك هالقطعة لأنها ضمن ميزانيتك (341 ألف ل.س) ومحتشم متل ما بتحبّي.",
        "reason_codes": ["BUDGET_FIT", "MODESTY_MATCH"],
        "quoted_price": { "amount": "341000.0000", "currency": "SYP" },
        "feedback": "NONE"
      }
    ],
    "outfit": null,                      // populated when she asked for a look
    "follow_ups": ["رتّبيلي إطلالة كاملة", "وريني أرخص"]
  },
  "brief": { "occasion": "evening", "budget_max": 900000, "chips": [ … ] }
}
```

Two fields carry the guarantees:

- **`reason_codes`** is the machine-readable version of `reason`. The sentence
  is rendered *from* the codes, so a card can never claim a match the ranker
  did not actually make.
- **`quoted_price`** is frozen when the card is produced, so a later price
  change cannot rewrite what she was shown.

Products travel through the same serializer the catalogue, search and discovery
use, so a stylist card is the *same* object as a search result and the client
renders it with the widget it already has.

### When nothing matches

A fully specified brief — black, size M, under 500k, modest, by Thursday — can
easily match nothing, and answering a paragraph with "لا يوجد" fails at the one
thing the feature exists for. Constraints are therefore dropped in a fixed
order (keywords, colour, size, budget headroom, budget entirely, then
neighbouring categories) and **every drop is reported in the reply**. Being
shown things over budget is acceptable; being shown them silently is not.

## Ohara Trend Engine (`/trends`)

Market analysis, trend scoring, demand forecasting and Arabic insights, built
on the tables the platform already writes. There is no separate analytics
service: the engine is a module inside this API, sharing the Prisma client, the
guards and `PricingModule`.

**The load-bearing rule: every number is arithmetic over rows.** A language
model is allowed to read a finished finding and rewrite the sentence around it.
It never decides what is trending, never computes a figure, and never sees a
customer. With `TREND_LLM_PROVIDER` unset — the default — Arabic templates do
the phrasing and nothing about the numbers changes.

### The pipeline

Runs nightly at 02:15 UTC (`TRENDS_SCHEDULER_ENABLED=true`), in one order,
because each stage consumes the previous one:

```
collect → score → forecast → search intelligence → insights → prune
```

| Stage | Writes | What it does |
| --- | --- | --- |
| Collect | `product_demand_daily`, `seller_demand_daily`, `category_demand_daily`, `trend_attribute_daily`, `search_term_daily` | One row per subject per day, from orders, offers, favourites, reviews and analytics events. Idempotent per day; the last three days are re-read every night because facts settle late. |
| Score | `product_trend_scores`, `category_trend_scores` | The deterministic 0–100 kernel over 7/14/30-day windows, with its nine components and a confidence stored beside the total. |
| Forecast | `trend_forecasts` | Holt's damped trend with a half-strength weekday index, per seller-product, per product and platform-wide, over 7/14/30-day horizons. |
| Search | `unmet_demand_signals` | Normalised queries, facet extraction, and the two kinds of miss: nothing came back, or something did and nobody wanted it. |
| Insights | `trend_insights` | Rules fire on the scores; Arabic templates phrase them; a model, if configured, phrases them better. |
| Prune | — | Deletes raw `analytics_events` past `RAW_EVENT_RETENTION_DAYS`. |

Every stage records a `trend_engine_runs` row: what it covered, how long it
took, how many rows it wrote, and why it failed.

### Trend Score

0–100 from nine weighted components, and **sales are only 17% of it** — that is
the point. A product being viewed, searched for and added to carts at an
accelerating rate outscores a steady seller, which is the moment a merchandiser
can still act.

| Component | Weight | | Component | Weight |
| --- | --- | --- | --- | --- |
| Sales velocity | 0.17 | | Acceleration | 0.11 |
| View growth | 0.13 | | Engagement | 0.10 |
| Conversion | 0.13 | | Search growth | 0.10 |
| Cart growth | 0.12 | | Quality (Wilson) | 0.08 |
| | | | Availability | 0.06 |

Each score carries a `stage` — `EMERGING`, `RISING`, `PEAKING`, `STEADY`,
`COOLING`, `DECLINING`, `DORMANT` — and a `confidence` from its exposure.
`EMERGING` is the one the engine exists for: steep, accelerating growth on a
product that has not sold much yet.

### Seller routes

Always scoped to the caller. No route accepts a seller id, and none would
honour one; the id comes from the token.

| Method | Path | Returns |
| --- | --- | --- |
| GET | `/trends/seller/overview?window=D7` | Headline, demand signals, trending, emerging, low-conversion alerts, stock opportunities, forecast, series, recommended actions |
| GET | `/trends/seller/products?window=&stage=&limit=` | Her products, scored |
| GET | `/trends/seller/products/:id?window=` | One product with its score history and daily facts |
| GET | `/trends/seller/forecast?horizon_days=14` | Her sales forecast |
| GET | `/trends/seller/insights` | Her recommended actions |
| PATCH | `/trends/seller/insights/:id` | `{ status }` — acknowledge, action or dismiss |

### Admin routes

`analytics:read` to read; `trends:manage` to act.

| Method | Path | Returns |
| --- | --- | --- |
| GET | `/trends/admin/overview?window=D7` | Everything below, in one payload |
| GET | `/trends/admin/categories?window=` | Category trends with in-stock coverage |
| GET | `/trends/admin/colors?days=&limit=` | Colour demand, with share now against a window ago |
| GET | `/trends/admin/prices?days=&limit=` | Price-band demand |
| GET | `/trends/admin/attributes?dimension=&scope_id=` | Any facet: colour, price band, brand, size |
| GET | `/trends/admin/products?window=&stage=&category_id=` | The leaderboard; `stage=EMERGING` and `stage=DECLINING` are the two ends |
| GET | `/trends/admin/products/:id?window=` | One product, 90 days of score history and daily facts |
| GET | `/trends/admin/search?days=&rising=` | Search terms with their miss rates |
| GET | `/trends/admin/unmet-demand?status=` | Questions the catalogue could not answer |
| GET | `/trends/admin/unmet-demand/:termKey/matches` | What would answer one today |
| PATCH | `/trends/admin/unmet-demand/:id` | `{ status, note }` — the buyer's sourcing workflow |
| GET | `/trends/admin/forecast?horizon_days=30` | Platform demand forecast |
| GET | `/trends/admin/sellers?days=&limit=` | Seller performance, with cancellation and return rates beside the growth |
| GET | `/trends/admin/opportunities?window=` | Category gaps, unmet searches and price-band gaps, ranked together |
| GET | `/trends/admin/insights` | Market insights |
| PATCH | `/trends/admin/insights/:id` | `{ status }` |
| GET | `/trends/admin/runs` | The last twenty pipeline runs |
| POST | `/trends/admin/recompute` | `{ lookback_days, rollup_only }` — refused while a run is in flight |

### Privacy

Enforced at the collection boundary, which is the last point the engine can see
a person at all.

- The fact tables carry counts and money. No user id, no session id, no query
  attributable to anyone.
- Distinct-viewer counts are k-anonymised at write time: below five they are
  written as zero, because a "1 viewer" beside a date is a person.
- Raw `analytics_events` — the only rows carrying an identity — are aggregated
  and then deleted on a 90-day retention clock.
- A model is sent a kind, a subject label and a bag of already-rounded figures.
  Never a customer, an order, or the catalogue.

### Where machine learning attaches

Three seams, all already load-bearing rather than aspirational:

- **Ranking.** `product_trend_scores.method` records which kernel wrote a row.
  A learned ranker becomes a second writer with a different `method`, and the
  two can be compared on the same days before anything is switched.
- **Forecasting.** `TrendForecastMethod.MODEL` already exists. A predictor
  implements `ForecastResult` and nothing downstream cares which arithmetic
  produced the points.
- **Narration.** The `TREND_LLM` provider seam, which takes findings and
  returns prose, and never the other way round.

## Settings

| Method | Path | Notes |
|--------|------|-------|
| GET/POST | `/addresses` | Shipping addresses |
| GET | `/coupons`, `/rewards`, `/notifications` | |
| GET/POST | `/payment-methods` | |

## Admin console

Reachable by every staff role — `SUPER_ADMIN`, `ADMIN`, `OPERATIONS_ADMIN`,
`SUPPORT_ADMIN`, `FINANCE_ADMIN`, `CONTENT_MODERATOR`, `SUPPORT` — and by no
other role. Which routes a given member of staff may call is decided per route
by the permission named below, resolved from `defaultPermissionsForRole` plus
any `UserRoleAssignment` rows. The role list is the outer fence; the permission
is the actual narrowing.

`/auth/me` returns the caller's resolved permission set alongside the user, so
the client can draw only the destinations that person can open. That is for
presentation; the server judges every request on its own.

### Lists

Every list below accepts `?page=&limit=&q=&status=` and answers with the same
envelope, so a console can page and say how much it is not showing:

```json
{ "items": [], "page": 1, "limit": 25, "total": 0, "has_more": false }
```

`q` and `status` are applied in the database, never to the page already in
hand. Some lists add one scalar beside the envelope — `pending` on seller
applications, `open` on the support, moderation and report queues.

| Method | Path | Permission | Notes |
|--------|------|------------|-------|
| GET | `/admin/stats` | `admin:dashboard` | Platform counters and 30-day trends |
| GET | `/admin/orders` | `order:read` | Searchable by number, recipient, phone |
| GET | `/admin/products` | `product:manage` | Searchable by title, slug, GTIN |
| PATCH | `/admin/products/:id` | `product:manage` | `{ status?, is_featured?, show_in_feed?, reason? }` |
| GET | `/admin/users` | `user:manage` | Rows carry `is_disabled` / `disabled_at` |
| PATCH | `/admin/users/:id` | `user:manage` | `{ role?, disabled?, reason? }`; refuses self-administration |
| GET | `/admin/sellers` | `seller_verification:review` | Sellers with verification status |
| GET | `/admin/seller-applications` | `seller_verification:review` | Pending first; `pending` count included |
| GET | `/admin/seller-applications/:id` | `seller_verification:review` | Full application + review history |
| PATCH | `/admin/seller-applications/:id/review` | `seller_verification:review` | `{ status, reason, rejection_reason? }`; reason is required |
| GET | `/admin/analytics` | `analytics:read` | 30-day series |
| GET | `/admin/financials` | `finance:read` | Gross, refunds, net, payments, recent ledger |
| GET | `/admin/commissions` | `finance:read` | Rules and ledger entries as one list, each row tagged `kind` |
| POST | `/admin/commissions/rules` | `finance:write` | `{ name, rate_bps, category?, seller_tier? }` |
| PATCH | `/admin/commissions/:id` | `finance:write` | `{ status }` on a ledger entry |
| GET | `/admin/support` | `support:read` | Priority first, then recency |
| PATCH | `/admin/support/:id` | `support:write` | `{ status?, priority? }` |
| GET | `/admin/moderation` | `content:moderate` | |
| PATCH | `/admin/moderation/:id` | `content:moderate` | `{ status, resolution? }` |
| GET | `/admin/reports` | `support:read` | |
| PATCH | `/admin/reports/:id` | `support:write` | `{ status }` |
| GET | `/admin/audit-logs` | `audit:read` | Searchable by action, category, actor |
| GET | `/admin/system-settings` | `authorization:manage` | A sensitive setting lists with `value: null` |
| POST | `/admin/system-settings` | `authorization:manage` | `{ key, value, sensitive? }` |

### The audit trail

Every write above records an `AuditLog` row in category `admin` naming the
actor, the subject, and what changed from what to what. The entries that an
incident review looks for — suspending an account, granting a privileged role,
deciding a moderation case, marking commission paid, changing a system setting
— are filed at `WARNING`. A sensitive setting's value is deliberately absent
from its audit entry: the log is read by more people than the setting is.

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
