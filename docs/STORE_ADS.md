# «إعلانات المتاجر» — store advertising

A boutique pays to be seen. What she pays decides how far she reaches: which
places her adverts may appear, whether she may choose who sees them, how many
run at once, how much each one costs, and how often she wins a slot when
several boutiques want the same one.

Everything here is labelled as an advert wherever a shopper sees it. A
shopper who cannot tell an advert from an answer stops trusting the answers.

## The plans

A plan is bought for 30 days, paid once from the boutique's earnings
(`SELLER_PAYABLE` → `PROMOTION_REVENUE`), and **never renews by itself**.
Each paid plan carries ad credit worth more than its price, spent before her
earnings are touched again.

| | عادي Free | فضي Silver | ذهبي Gold | ماسي Diamond |
|---|---|---|---|---|
| Price / month (SYP) | 0 | 25,000 | 60,000 | 120,000 |
| Ad credit included | — | 30,000 | 80,000 | 180,000 |
| Discount on every campaign | — | 10% | 20% | 30% |
| Campaigns at once | 1 | 3 | 6 | 15 |
| Placements | search, category | + top of the feed | + home spotlight | all |
| Audience targeting | everyone | by governorate | + followers, past buyers, interested, new shoppers | same as Gold |
| Share-of-voice weight | 1× | 2× | 3× | 5× |
| Followers told of a new campaign | — | — | weekly at most | weekly at most |
| First in «متاجر مميزة», with a badge | — | — | ✓ | ✓ (ahead of Gold) |

The numbers live in `backend/src/modules/promotions/ad-plans.ts`. Prices can
be overridden from the console with the `promotions.plan_prices_syp` system
setting (`{"SILVER": 25000, ...}`).

**Upgrading** ends the current plan now and carries its unused credit into
the new one. **Renewing** or buying a lower plan queues the new one to start
when the current one ends. Nothing a boutique paid for is lost or cut short.

## The placements

| Placement | Where | Slots |
|---|---|---|
| `SEARCH` | Above organic results, only for a search that would have returned the piece | 3 |
| `CATEGORY` | Top of the category shelf the piece belongs to (whole subtree) | 3 |
| `FEED_TOP` | Her own public post, pinned at the head of the community feed («أعلى المنشورات») | 1 |
| `HOME_SPOTLIGHT` | «مختارات مميزة», near the top of the home page | 3 |

Daily rates (SYP, before discount): search 1,500 · category 1,000 · feed
2,500 · home 4,000. Override with `promotions.rate_card_syp`. The older
`promotions.min_daily_fee_syp` floor still applies.

A targeted campaign costs 80% of one shown to everyone — fewer women see it.

## Who sees an advert

- **Everyone** — every shopper, signed in or not.
- **Targeted** — signed-in shoppers only: in one of the chosen governorates
  (if any were chosen) **and** in one of the chosen groups (if any were
  chosen). Groups: her followers, women who bought from her, women who
  viewed / favourited / carted that kind of piece in the last 30 days, women
  who have never ordered.

The boutique is told **how many** women her audience holds, never who they
are. A guest sees only campaigns meant for everyone.

The feed and the home spotlight are capped at **three showings per shopper
per day** per advert. Search and category are not capped — she asked.

A shopper's own «غير مهتمة» and mutes apply to the pinned feed post exactly as
they apply to the feed.

## Who wins a slot

Not "highest bid takes all", and not "oldest first". Each eligible advert is
picked with probability proportional to

    plan weight × what she paid per day

(Efraimidis–Spirakis weighted sampling). A Diamond boutique paying the rate
card is shown five times as often as a Free one paying the same — and the
Free one that paid is still shown. A boutique may name a fee above the quote
to raise her share; she may never pay below it.

Only listings a shopper could buy right now are served: active offer, in
stock, live product.

## What she is told

`GET /ads/overview`, `GET /ads/campaigns`:

- **Reach** — distinct women who saw it (from `ad_exposures`).
- **Taps**, **views**, click-through rate, and the platform's own rate beside
  it (only once there are 100 impressions to compare against).
- **Orders and sales from the advert** — an order for the advertised offer,
  from this boutique, not cancelled, placed by a woman who tapped the advert
  in the 7 days before it.
- **Return per lira** — attributed sales ÷ spend.

Impressions and taps are reporting only; nothing about the money reads a
number a phone can send.

## The smart parts

All arithmetic over what the platform already records — no guessing:

- **Quote** (`POST /ads/quote`): the price line by line, whether her plan
  allows it and which plan would, how many shoppers the audience holds, and
  her expected share of the slot against the campaigns live today.
- **Suggestions** (`GET /ads/suggestions`): which of her pieces to promote,
  and why — loved but not bought, best seller, new and barely seen — each with
  a suggested placement, audience and duration.
- **Plan recommendation**: what last month's campaigns would have cost on
  each plan, and the cheapest one.

## Endpoints

Seller only, always about the caller:

| Method | Path | |
|---|---|---|
| GET | `/ads/plans` | Her plan, credit, every plan, the recommendation |
| POST | `/ads/plans/subscribe` | `{tier}` — buy, upgrade or renew |
| POST | `/ads/quote` | `{offer_id, placement, days, audience?}` |
| GET | `/ads/suggestions` | Smart picks |
| GET | `/ads/overview` | Totals and the insight |
| GET | `/ads/audience/governorates` | Where her shoppers live, with counts |
| GET | `/ads/campaigns` | Her campaigns with reach and attributed sales |
| POST | `/ads/campaigns` | Create and (unless `launch: false`) charge and start |
| PATCH | `/ads/campaigns/:id/status` | Pause / resume |

Refusals carry a `code` the app words: `INSUFFICIENT_BALANCE`,
`CAMPAIGN_LIMIT`, `FEED_POST_REQUIRED`, `PLACEMENT_LOCKED`,
`TARGETING_LOCKED`, `INTEREST_TARGETING_LOCKED`.

The app sends an `Idempotency-Key` on buying a plan and launching a campaign,
so a retried tap on a slow line is one charge, not two.

Shopper-facing:

- `GET /content/feed` — the first page of the plain home feed may lead with a
  row carrying `sponsored: {promotion_id, offer_id, placement, store_tier}`.
- `GET /discovery/home-content` — `sponsored_spotlight: [...]` and
  `featured_stores[].ad_tier`.
- Search and category slots now carry `sponsored_store_tier`.
- `POST /sponsored/clicks` — open to guests; a signed-in tap is also recorded
  against her, which is what attribution reads.

## Data

- `store_ad_subscriptions` — a plan with a window, its price, credit granted
  and used.
- `product_promotions` — gained `content_id` (the pinned post), the audience
  columns, and `credit_applied`.
- `ad_exposures` — one row per shopper per advert per day: impressions,
  taps, last tap.

Migration: `backend/prisma/migrations/20261029120000_store_advertising`.
