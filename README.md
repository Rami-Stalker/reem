# Ohara

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

Fails on any English literal in presentation code. Ohara is Arabic-first; an
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

## Store advertising

«إعلانات المتاجر»: a boutique pays to be seen, and what she pays decides how
far she reaches. Four plans — عادي، فضي، ذهبي، ماسي — unlock more placements
(top of search, the category shelf, her post pinned above the community feed,
the home spotlight), audience targeting (by governorate, then followers, past
buyers, interested shoppers, new shoppers), more campaigns at once, a
discount, ad credit worth more than the plan costs, a badge, and a bigger
share of every contested slot.

Before paying she sees the price line by line, how many women the audience
holds and her share of the slot; afterwards, the women reached and the orders
that came from the advert. Every advert is labelled as one, a shopper sees
the same one at most three times a day, and plans never renew by themselves:
[docs/STORE_ADS.md](docs/STORE_ADS.md).

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

## My occasions

«مناسباتي»: she writes down a wedding, Eid or birthday, and Ohara helps her get
ready — a countdown, a look from her closet, what that look is missing, the
salon, the gift, and a reminder a week, three days and one day before. It also
warns her when the people she named for the day have already seen the outfit.

The look is a closet look and the salon is an appointment; the occasion only
points at them, and its checklist is read from their state on every request:
[docs/OCCASIONS.md](docs/OCCASIONS.md).

## Reviews from women my size

«تقييمات من بمقاسي»: a product review can say how the piece fit and carry up
to four photographs of the piece. The size she bought is read from her
delivered order rather than typed. The product page shows a fit summary and
filters for «من بمقاسي» and «مع صور», matched against the height and size she
keeps in «مقاساتي». Those are never shown to anyone, on her reviews or
anywhere else; the server uses them only for matching and the anonymous
summary:
[docs/FIT_REVIEWS.md](docs/FIT_REVIEWS.md).

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

### App size

Build for the Play Store with `appbundle` (above): Play then delivers to each
phone only the native code for its own processor. A plain
`flutter build apk --release` is a *universal* APK — it carries the Flutter
engine and the compiled Dart code three times over (`arm64-v8a`,
`armeabi-v7a`, `x86_64`), stored uncompressed, which is why it lands around
70 MB while a phone only ever uses one third of it.

To hand an APK around directly (WhatsApp, a website), build one per processor
and send the `arm64-v8a` one — every phone from the last several years:

```bash
flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=build/symbols \
  --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.reem.shop
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

`--obfuscate --split-debug-info` moves Dart symbol tables out of the binary
(a few MB smaller); keep `build/symbols/` for each release, it is what turns a
crash stack trace back into readable names (`flutter symbolize`).

Debug builds (`flutter run`) are always far larger than release ones — never
judge the size from them. To see what takes the space in a release:

```bash
flutter build apk --release --target-platform android-arm64 --analyze-size
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
| [STORE_ADS.md](docs/STORE_ADS.md) | «إعلانات المتاجر»: the plans, the four placements, targeting, how a slot is won, attribution, and the `/ads` endpoints |
| [SALONS.md](docs/SALONS.md) | «الصالونات والجمال»: the booking invariant, availability, statuses, the two jobs, and why an appointment carries no money |
| [FIT_REVIEWS.md](docs/FIT_REVIEWS.md) | «تقييمات من بمقاسي»: fit facts and photos on reviews, the privacy rules for height and size, and who counts as "my size" |
| [OCCASIONS.md](docs/OCCASIONS.md) | «مناسباتي»: the derived checklist, the countdown and why it rings once per mark, and the repeat warning |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | **Run one API process.** The single-instance constraint, the nightly job order, production env guards |
| [production-gap-analysis.md](docs/production-gap-analysis.md) | Pre-launch audit: what is complete, what is thin, what is missing, in priority order |
| [production-launch-report.md](docs/production-launch-report.md) | **Read before deploying.** Launch readiness: what was tested and fixed, remaining risks, external dependencies, and the three blockers |
| [docs/client/](docs/client/) | Client requirement questionnaires |
