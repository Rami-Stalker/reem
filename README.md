# Reem

Women-focused social-commerce platform. A Flutter client at the repository
root, a NestJS + PostgreSQL API in [`backend/`](backend/).

## Repository layout

```text
lib/                 Flutter client (see docs/ARCHITECTURE.md)
  main.dart            entry point
  app/                 MyApp + AppBootstrap
  core/                cross-cutting: design system, network, router, DI, ...
  features/            feature modules, each with data/ domain/ presentation/
  l10n/                generated localization output
assets/fonts/        bundled Cairo + Playfair Display
test/                widget, visual-preview, and API contract tests
backend/             NestJS API, Prisma schema, migrations, seed
docs/                architecture, database, API, and client-requirement docs
tools/architecture/  structural checks that the analyzer cannot express
```

## Running the client

Requires the Dart SDK matching `environment.sdk` in `pubspec.yaml` (`^3.11.5`).

```bash
flutter pub get
```

```bash
flutter run
```

## Running the API

From `backend/`. The first command brings up PostgreSQL in Docker; the second
applies migrations, generates the Prisma client, and seeds the demo dataset.
Use `db:setup` alone to migrate without seeding — the seed empties every
table before it writes, so it is no longer part of "set up the database".

```bash
npm install && npm run db:up
```

```bash
npm run db:setup:demo && npm run dev
```

See [`backend/README.md`](backend/README.md) for the endpoint surface, auth
model, and database operations.

## Checks

```bash
flutter analyze
```

```bash
flutter test
```

Seven structural checks guard the layout. All exit non-zero on failure.

```bash
node tools/architecture/check-flutter-boundaries.mjs
```

Fails when a `domain/` library imports Flutter, Riverpod, Dio, `go_router`, or
a `data/`/`presentation/` sibling; also prints advisory debt queues.

```bash
node tools/architecture/check-design-system.mjs
```

Fails when feature code names a raw colour, hand-assembles a `TextStyle`, or
spaces itself off the 4px grid. See [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md).

```bash
node tools/architecture/check-localization.mjs
```

Fails on any English literal in presentation code. Reem is Arabic-first; an
English string in a widget is a screen a customer cannot read. A literal that
genuinely is not copy — a dialling mask, an intl date pattern, a record id the
server matches on — carries an inline `// l10n-ignore: <reason>`.

```bash
node tools/architecture/find-unreachable-dart.mjs
```

Fails when a library under `lib/` is reachable from neither `main.dart` nor a
test.

```bash
node tools/architecture/check-api-contract.mjs
```

Fails when the client declares a path the API does not serve — a screen built
on a route that was renamed, or on a feature the backend never had. Neither
half fails to compile on its own, so nothing else catches it.

```bash
node tools/architecture/check-icon-labels.mjs
```

Fails when an icon-only button carries no `tooltip`. A button whose whole
content is an icon has no text for a screen reader to read, so Flutter
announces it as "button" and nothing more — the same four letters for "add to
cart", "remove from favourites" and "delete".

```bash
node tools/architecture/check-image-budgets.mjs
```

Fails when a network image does not bound its own decode. A decoded bitmap
costs four bytes per pixel of the *source file*, not of the widget — a 2400px
photograph in a 138pt card is 30 MB of RAM for 0.2 MB of visible detail. A
smaller server-side variant bounds the download; `memCacheWidth` bounds the
decode, and they are different costs.

## Response caching

GET requests are cached at the transport layer — read-through, coalesced, and
served stale when the connection drops. What is cached and what deliberately is
not lives in [docs/CACHING.md](docs/CACHING.md).

## Notifications

Push that reaches a woman who has closed the app, not only a row in an inbox
she has to open to find. Six Android channels so she can mute the noise without
silencing her orders, a frequency cap that counts across every sender, and a
delivery worker that retires dead device tokens instead of pushing to them for
ever. Configuring Firebase and reading a delivery that did not arrive:
[docs/NOTIFICATIONS.md](docs/NOTIFICATIONS.md).

With no Firebase project configured the whole thing degrades to nothing on
purpose: the build succeeds, the app runs, and the API records each push as
skipped rather than claiming it was sent.

## Product interactions

Every product supports Like, Share, Save, Repost and Comments — as a post, the
five sit on the card; as a grid tile, a rail card or a search result, the like
sits on the tile and the rest are on the product page. They belong to the
*product*, so a piece liked on the home grid is liked on its own page and on a
boutique's shelf.

The affordance is installed once, above the navigator, and every product
surface asks for it — so a grid written next year gets it by construction
rather than by review: [docs/PRODUCT_INTERACTIONS.md](docs/PRODUCT_INTERACTIONS.md).

## Shareable links

A product link pasted into WhatsApp shows the photograph, the name and the
price, and opens the product — inside the app on a phone that has it, on a
real page on one that does not. The same shape covers posts, reels, stories,
profiles, boutiques, collections and room invites.

Links used to point at `https://reem.shop`, a host that has never resolved, so
every share ended on the browser's error page. They point at the API's own
origin now, which serves a landing page with Open Graph tags for each of them
— overridable with one variable when a custom domain is attached. Making them
open the app instead needs a signing fingerprint and an Apple team id, and
until those exist the links still work as web pages:
[docs/SHARE_LINKS.md](docs/SHARE_LINKS.md).

## Salons and beauty

«الصالونات والجمال»: a woman finds a salon near her, picks a service, a day and
an hour, and books. The salon confirms, serves her, and she rates it. Home
service, packages and offers are part of the model rather than a later bolt-on.

It is not a second application. A salon is owned by a `User`, the button that
messages it opens the chat that already exists, its notices ride the
notification service, a home appointment uses the address book she keeps for
parcels, and its link shares like a product's.

The one invariant is that no two women hold the same chair at the same hour,
and because durations vary and a salon may have four chairs, that is a `FOR
UPDATE` overlap count rather than a unique index. An appointment carries no
money — she pays at the chair: [docs/SALONS.md](docs/SALONS.md).

## Resilience

Crash handling, PII-safe error reporting with breadcrumbs, and the offline
write queue that keeps a tap taken on a dead connection: see
[docs/RESILIENCE.md](docs/RESILIENCE.md).

## Release builds

The app ships as `shop.reem.app` on every platform — Play Store identity is the
applicationId and cannot be changed after the first upload.

Release signing reads `android/key.properties`, which is git-ignored along with
the keystore it names. Without it the build falls back to the debug key and
warns: `flutter run --release` still works, but the artifact cannot be
published. Copy [`android/key.properties.example`](android/key.properties.example)
and follow the `keytool` line in it to create the keystore.

Point the build at a real API. Without `API_BASE_URL` the client talks to
localhost, which is right for development and useless in a release:

```bash
flutter build appbundle --release --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.reem.shop
```

Launcher icons are painted from the design-system tokens rather than exported
from a checked-in artwork file. Regenerating rewrites every Android density,
every iOS slot, the web icons, and the store artwork under `docs/brand/`:

```bash
flutter test tools/icons/generate_app_icons.dart
```

## Documentation

| Document | Covers |
| --- | --- |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Client layering, where shared code lives, structural checks, known debt |
| [DATABASE.md](docs/DATABASE.md) | Schema and data model |
| [BACKEND_API.md](docs/BACKEND_API.md) | Endpoint surface |
| [identity-authorization-architecture.md](docs/identity-authorization-architecture.md) | Identity, OTP, devices, roles |
| [PRODUCT_INTERACTIONS.md](docs/PRODUCT_INTERACTIONS.md) | Like/Share/Save/Repost/Comments on every product surface, and the one store behind them |
| [SHARE_LINKS.md](docs/SHARE_LINKS.md) | Share links, App Links / Universal Links, the landing pages, and the two well-known files |
| [SALONS.md](docs/SALONS.md) | «الصالونات والجمال»: the booking invariant, availability, statuses, the two jobs, and why an appointment carries no money |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | **Run one API process.** The single-instance constraint, the nightly job order, production env guards |
| [production-gap-analysis.md](docs/production-gap-analysis.md) | Pre-launch audit: what is complete, what is thin, what is missing, in priority order |
| [production-launch-report.md](docs/production-launch-report.md) | **Read before deploying.** Launch readiness: what was tested and fixed, remaining risks, external dependencies, and the three blockers |
| [docs/client/](docs/client/) | Client requirement questionnaires |
