# Feed ranking

How the community feed («اكتشفي»), the reels, the home page's posts and the
story tray are ordered for each woman. None of them is newest-first any more,
unless an operator switches ranking off.

| Surface | Endpoint | Ordered by |
| --- | --- | --- |
| Community feed | `GET /content/feed` (no filter, no channel) | The feed ranker, `feed` weights |
| Reels | `GET /content/reels` | The feed ranker, `reels` weights (watch time leads) |
| Home page posts | `GET /posts/feed` | The feed ranker, posts only |
| Story tray | `GET /content/stories`, `GET /stories` | The tray order |

A filtered or channel feed (a boutique's page, `content_type=…`, a product's
rail, «أتابع») is a list she asked for and stays newest-first.

## The pieces

```
backend/src/modules/commerce-content/ranking/
  feed-rank.ts              the kernel: pure scoring, diversity, the tray order
  feed-rank.spec.ts         its unit tests
  feed-ranking.service.ts   candidates, her signals, sessions, «already shown»
  feed-ranking.integration.spec.ts
```

The kernel takes plain numbers and returns an order, so every rule in it is
tested without a database. The service gathers those numbers in a handful of
batched queries.

## Candidates

Up to about 700 pieces from five pools, each under the platform's one
visibility rule and her own «غير مهتمة» and mutes:

| Pool | Window | Size |
| --- | --- | --- |
| Fresh: the newest | 3 days | 150 |
| Doing well: most engaged | 7 days | 150 |
| Evergreen: the month's best | 30 days | 60 |
| Everyone she follows | 7 days | 200 |
| Her categories (from what she saved, viewed, bagged and bought) | 21 days | 150 |

Stories are never feed candidates; they live in the tray.

## The score

```
score = relevance × quality lift × freshness × seen × doubt × own
```

- **Relevance:** a weighted sum of:
  - following (`follow`);
  - her history with the author (`affinity`): likes, saves, comments, product taps and orders over 60 days;
  - her interest in the piece's categories (`interest`);
  - its engagement rate (`engagement`), its momentum (`momentum`) and its sales (`commerce`);
  - the boutique's standing (`quality`), from `seller_rank_score` plus verification;
  - for reels, watch time per view (`watch`).
- **Engagement rate** is smoothed: three likes on three views does not beat
  three hundred on a thousand.
- **Quality lift:** `0.6 + 0.8 × engagement`, so a superb older post can beat
  a dull new one.
- **Freshness:** a half-life (30 h for the feed, 72 h for reels) with a floor.
- **Seen:** each time the feed already showed it to her, ×0.45, down to a
  limit. A piece she already liked or saved ×0.2.
- **Doubt:** reported pieces are not amplified while moderation decides.
- **Own:** her own post leads her feed for its first two hours.

Then, greedily:
- the same author never appears twice in a row while there is an alternative,
  and at most three times in ten;
- every Nth place (8 in the feed, 4 in reels) goes to a good account she does
  not follow and the feed rarely shows (`new_voice`);
- a small seeded jitter keeps two visits from being identical, while one
  session stays reproducible.

Every organic row carries `rank_reason`: `following`, `for_you`, `trending`,
`new_voice` or `popular`. The app shows a chip for the three that need
explaining (`for_you` «مقترح لكِ», `trending` «رائج الآن», `new_voice`
«صوت جديد»). A followed account needs no chip, and `popular` is the guest feed.

## Sessions and paging

The first page ranks the candidates once and keeps the order for 25 minutes.
The cursor is `r.<session>.<offset>`, so scrolling never reshuffles what she
already passed. When the order runs out, the feed continues newest-first with
`r.<session>.t.<keyset>`, skipping everything the session showed, so it never
stops and never repeats. A page where the order runs out is topped up from
that continuation, so no page comes back short.

- **Guests** share one ranking per two-minute bucket (`g<bucket>`). A
  guest cursor older than the session is replaced, so nobody can make the
  server rank by inventing session ids.
- **`/posts/feed`** pages by number. It keeps one session per woman (`home`),
  re-ranked on page 1 once it is three minutes old, so a pull to refresh
  brings a new order.

Every row served to a signed-in woman is recorded in `feed_seen` (user,
content, times served, last served). That is what the seen penalty reads. It
also tracks how much exposure each author already has, which decides who is a
new voice. `FeedRankingService.sweepSeen` deletes rows older than 14 days
every night.

## Adverts in a ranked feed

- **Page 1** leads with the paid `FEED_TOP` post, as before.
- **Every later page** of the same scroll carries one more, four places in,
  and never one the scroll already showed.
- A post shown as an advert does not come back further down as an organic
  row.
- Each is labelled «مُموَّل» and still obeys her mutes and the daily frequency
  cap.

Reels carry no adverts.

## Stories

The tray order:
1. her own ring;
2. every ring with something unseen;
3. the rings she finished.

Within a band, closeness decides:
- following;
- her history with the author;
- among shops she does not follow, the boutique's paid plan (never above
  someone she follows);
- recency breaks ties.

`/stories` returns a flat list; it is laid out shop by shop in this order,
because the app groups by first appearance.

## Reels and watch time

The app times how long each reel is on screen. It sends `WATCH_TIME` when she
swipes on, leaves the screen or puts the app away:
- under one second is not sent;
- anything over ten minutes counts as ten.

The reels weights lean on it more than on hearts.

## Tuning and the off switch

Both are rows in `system_settings`, read on each ranking. No deploy is needed.

| Key | Value |
| --- | --- |
| `feed.ranking_enabled` | `false` returns every surface to newest-first at once |
| `feed.ranking_weights` | `{ "feed": { "follow": 0.35 }, "reels": { "watch": 0.25 } }`: any subset; non-numbers are ignored |

Any failure inside the ranker serves the feed newest-first, and the tray in
creation order. Ranking can make a feed better; it must never take one down.
