# Reem Commerce Content Platform Roadmap

## Current Architecture Assessment

The existing backend is already strong in several useful ways: it has NestJS modules, Prisma repositories, global authentication, authorization policies, scheduled jobs, event emission, notification fanout, analytics primitives, and clean feature boundaries for products, posts, stories, search, rewards, and admin operations.

The main gap is that social commerce content is split by concrete tables and services. `posts` are product-bound rows, and `stories` are ephemeral media rows. That makes it hard to add reels, campaigns, collections, live shopping, interactive offers, polls, AI-generated content, or future formats without adding new tables, controllers, serializers, feed logic, analytics logic, and moderation paths each time.

## Weaknesses Identified

- Content types are hardcoded as modules instead of configured as platform data.
- Publishing lifecycle is incomplete: drafts, scheduled publishing, review, rollback, archive, expiration, and version history are not unified.
- Feed logic is duplicated around concrete objects and lacks one ranking/caching boundary for future algorithms.
- Product tagging exists only indirectly through posts; content cannot attach multiple products, variants, coordinates, or commerce actions.
- Story behavior is isolated from the rest of publishing, which blocks shared analytics, moderation, scheduling, localization, and recovery.
- Analytics counters are split across models and do not provide a universal event ledger for impressions, views, conversions, reactions, replies, watch time, and revenue.
- Moderation exists as generic cases but not as a first-class publishing state machine.

## Implemented Foundation

The first platform slice introduces a universal content object model:

- `CommerceContentTypeDefinition`: configurable content type registry with JSON schema, UI schema, lifecycle, and capabilities.
- `CommerceContent`: one extensible entity for posts, stories, offers, collections, live streams, campaigns, and future formats.
- `CommerceContentMedia`: ordered media attachments with image/video metadata, placeholders, thumbnails, and streaming URLs.
- `CommerceContentProductTag`: many-product and variant-aware shoppable tags with coordinates and metadata.
- `CommerceContentVersion`: version snapshots for rollback and auditability.
- `CommerceContentEvent` and `CommerceContentViewer`: analytics event ledger and unique-viewer tracking.
- `CommerceContentModerationAction`: review trail for manual or AI moderation decisions.

New API surfaces:

- `GET /content-types`
- `POST /content-types`
- `POST /seller/content`
- `GET /seller/content`
- `GET /seller/content/:id`
- `PATCH /seller/content/:id`
- `POST /seller/content/:id/publish`
- `POST /seller/content/:id/archive`
- `POST /seller/content/:id/rollback/:version`
- `GET /seller/content/:id/analytics`
- `GET /content/feed`
- `POST /content/:id/events`
- `POST /admin/content/:id/moderation`

## Enterprise Implementation Roadmap

1. Compatibility adapters
   - Mirror existing `Post` and `Story` creation into `CommerceContent`.
   - Add read adapters so legacy clients can consume universal content without breaking.
   - Backfill existing posts and stories into content objects.

2. Seller publishing workspace
   - Replace separate create-post and create-story flows with a content-type driven composer.
   - Add autosave, drafts, scheduled publishing, bulk actions, localization, and product tag editing.
   - Introduce offline publish queue on the Flutter client.

3. Feed engine
   - Add ranking strategy interfaces for home, following, store, category, story, offer, video, and sponsored feeds.
   - Move cache storage behind Redis-compatible infrastructure.
   - Add cursor pagination and feed experiment metadata.

4. Media platform
   - Add upload sessions, media processing states, duplicate detection, thumbnails, blur placeholders, transcoding, adaptive streaming, and CDN asset records.
   - Move URL-only media references to managed media assets.

5. AI publishing
   - Add provider interfaces for caption generation, translations, hashtag generation, layout suggestions, spam detection, and publish-time recommendations.
   - Store AI provenance, confidence, prompt version, model version, and human override metadata.

6. Moderation and trust
   - Add AI preflight moderation before publish.
   - Add review queues, report escalation, shadow moderation, policy bundles, and safety labels.
   - Make moderation rules configurable by content type, seller level, region, and risk score.

7. Commerce conversion
   - Add content-driven cart, wishlist, comparison, bundles, upsell, and purchase attribution.
   - Feed content analytics into product and seller reputation systems.

8. Scale and reliability
   - Partition high-volume event tables by time and content id.
   - Move fanout and media workflows to queues.
   - Add idempotency keys for publishing and analytics events.
   - Add OpenTelemetry traces, SLO dashboards, and replayable event streams.

## Architectural Direction

Keep concrete experiences like posts, stories, offers, live streams, and campaigns as configuration plus optional plugins. The stable core should remain:

- content type registry
- content lifecycle state machine
- product/media attachments
- feed/ranking interfaces
- analytics event ledger
- moderation workflow
- AI/provider interfaces
- notification/event integration

That prevents future features from becoming new silos and gives Reem one commerce publishing platform instead of many unrelated social features.
