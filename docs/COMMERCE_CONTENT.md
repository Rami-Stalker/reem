# Reem Commerce Content Platform

## What it is

One content platform for everything social and shoppable: posts, reels and
stories, published by boutiques *and* by shoppers, with one feed, one analytics
ledger and one moderation path.

`CommerceContent` and its satellites are the whole object model. There are no
separate `posts` or `stories` tables any more — they were folded in, and
`/posts/*` and `/stories/*` survive only as adapters that speak their original
JSON contract over the new tables.

## The object model

| Table | Holds |
| --- | --- |
| `commerce_content_type_definitions` | The **format registry** — `product_post`, `reel`, `story`, `flash_offer`, `collection`, `live_stream`. A format is a row: its JSON schema, its capabilities (`video_required`, `max_duration_seconds`, `audiences`) and its default channels. Adding a format, or opening one to shoppers, is a row edit. |
| `commerce_contents` | One piece of content. **Author-owned** (`author_id`), with `author_kind` recording what she was when she wrote it and `author_is_public` mirroring her page's visibility. |
| `commerce_content_media` | Ordered media, with `streaming_url`, `duration_ms`, `blur_hash`. |
| `commerce_content_product_tags` | Multi-product, variant-aware, x/y hotspots — plus `basis` and `source_order_item_id`, which record *why* the tag was allowed. |
| `commerce_content_reactions` | A like on a post, an emoji on a story. One per woman per piece. |
| `commerce_content_saves` | Her saved shelf. |
| `commerce_content_comments` | One level of replies, hidden rather than deleted. |
| `commerce_content_reshares` | «أضيفي إلى صفحتي» — a pointer to the original, never a copy. |
| `commerce_content_attributions` | A **projection**: which boutiques a piece earns credit for, and why. |
| `commerce_content_versions` / `_events` / `_viewers` / `_moderation_actions` | Version snapshots, the analytics ledger, unique viewers, and the moderation trail with its reason. |

## The five rules worth knowing

**1. A reshare is a pointer.** Adding somebody's post to your page creates an
edge, not a second piece of content. So a price correction or a takedown on the
original reaches every page it was ever added to, and interactions attach to the
original — two women reshare the same look, a third likes it on both pages, and
the boutique sees one like.

**2. Tagging a product requires entitlement.** A boutique may tag a product it
holds a **live** offer on; a shopper may tag one that was **delivered** to her.
The bases are OR'd, never switched on role — a boutique owner who bought a dress
elsewhere may post about it. `ProductTagPolicyService` is the single answer, used
by both the write path and the picker, and the proof is recorded on the tag.

**3. Her page is hers.** A shopper's profile is private by default. Opening it
makes her followable and lets her content reach a feed; `author_is_public` and
`resharer_is_public` mirror the flag and are flipped in the same transaction, so
there is no window where they disagree. They fail closed.

**4. A boutique sees who promoted it, within the privacy rule.** Counts always;
names only for women whose pages are open. The decision is made once, in
`serializePromoter`, at read time — so closing her page takes her name off the
boutique's screen on the next load rather than at the next rebuild.

**5. Nothing is removed silently.** A takedown sets `REMOVED`, writes a
moderation action with a mandatory reason, writes an `AuditLog` at WARNING, and
notifies the author with the reason in Arabic. The reason is demanded in three
places — the DTO, the service, and a CHECK constraint — and removal is
reversible.

## API

```
GET    /content/feed | /reels | /following | /stories | /saved     cursor-paged
GET    /content/users/:id            her page: own content ∪ reshares
GET    /content/products/:id         the UGC rail on a product
GET    /content/taggable-products    what she may tag, and why
POST   /content                      author — role-aware, registry-gated
POST   /content/:id/publish | /archive | /rollback/:v
POST   /content/:id/like | /save | /share | /reshare   (DELETE to undo)
GET    /content/:id/comments   POST /content/:id/comments
POST   /content/:id/report     POST /content/:id/events
GET    /seller/content/analytics/{overview,reshares,promoters}
GET    /admin/content   POST /admin/content/:id/{remove,reinstate}
PATCH  /users/me/profile-visibility
```

`/content/*` feeds are **keyset**-paged (`{data, pagination: {limit,
has_next_page, next_cursor}}`). A feed grows at the head, so offset paging shows
duplicates and skips rows. The legacy `/posts/*` routes keep offset paging
because their contract promises `total` and `total_pages`.

## Visibility

One predicate, shared by every feed (`ContentFeedService.visibilityWhere` and
its SQL twin): published, not rejected, unexpired, and *(mine, or PUBLIC with a
public author, or FOLLOWERS with a public author and a follow edge)*.
`FOLLOWERS` was an enum value nothing honoured before this.

The page timeline and the following feed are a `UNION ALL` over content and
reshares, hydrated by id. Deliberately **not** a materialised timeline: a
takedown has to vanish from every page the post was added to, and with a live
query that is automatic — with a projection it is a fan-out where one missed row
leaves removed content visible.

## Counters

`reactions_count`, `saves_count`, `replies_count` and `shares_count` have
exactly one writer: `ContentInteractionsService`, inside the same transaction as
the row. `POST /content/:id/events` still records the gesture in the ledger but
no longer touches those totals — both paths live would have double-counted every
like, invisibly and permanently.

## Still open

- **Reels have no thumbnail pipeline.** `sharp` derives image variants; a video
  gets a blur-hash-and-poster fallback until a frame extractor exists.
- **`ContentPerformanceDaily`** — the per-content daily fact table for 30-day
  charts is designed but not built; the live counters serve the current screens.
- **Ambassador rewards** are not built. The data is ready for them:
  `commerce_content_reshares` carries `campaign_key` and `coupon_id`, and the
  attribution table answers "who promoted what" in one index scan.
- **The tag policy ships in log-only mode.** `CONTENT_ENFORCE_TAG_POLICY=true`
  turns it on. The old check had no offer-status filter, so boutiques with
  archived listings can tag today; read the warnings before enforcing.
- **Comment likes** have no table. `likes_count` is a literal `0` on the wire,
  as it always was — adding the counter without a writer is what
  `products.likes_count` was deleted for.
