# Shareable links

What a woman pastes into WhatsApp, and what happens when her friend taps it.

## The defect this replaces

Every link Reem had ever shared pointed at `https://reem.shop`. That host has
never existed — it is NXDOMAIN, not a parked page — so nothing resolved:
WhatsApp drew no preview because there was no server to ask, and the tap ended
on the browser's «تعذّر الوصول إلى الموقع» page. Three further gaps sat behind
it:

- No `https` App Links or Universal Links were declared on either platform, so
  even with Reem installed a link opened a browser.
- The link shapes did not match any route. `/product/<id>` is not the app's
  product page (`/product-details?id=…`), and `/p/<id>` mapped to
  `/content/:id`, which had a path constant, a route *name* — and no route, no
  screen, and no backend endpoint.
- `_publicRoutes` in the auth guard is written in route patterns (`/user/:id`)
  and the guard compared them against concrete locations (`/user/abc`), so ten
  routes deliberately listed as public were in fact gated. A shared link is
  precisely a stranger arriving at one of them.

## The shapes

One path per kind, and three addresses derived from it:

| Kind | Share path | In-app route |
|---|---|---|
| Product | `/product/:id` | `/product-details?id=:id` |
| Post, reel, story | `/p/:id` | `/content/:id` |
| Profile | `/user/:id` (short form `/u/:id`) | `/user/:id` |
| Storefront | `/user/:id/products` | `/user/:id/products` |
| Collection | `/collection/:key` | `/collection/:key` |
| Room invite | `/rooms/join/:slug` | `/rooms/join/:slug` |
| Referral | `/invite/:code` | — web only |

The definition lives in two mirrored files, and the test suites on both sides
assert the same strings:

- `backend/src/modules/links/share-links.ts`
- `lib/core/shared/services/share_links.dart`

Adding a kind — a saved look, an outfit, a drop — is an entry in each, a
resolver in `share-preview.service.ts`, a route on `LinksController`, and a
`GoRoute` if the app should open it.

A referral link is deliberately **not** claimed by the app. An invitation is
sent to somebody who does not have Reem; having the app swallow it would hide
the download button from the one person it was written for.

## What happens when a link is tapped

**App installed, link opened from a browser or an SMS.** Android App Links and
iOS Universal Links hand the URL straight to the app. No web page is fetched
and no chooser appears. GoRouter's top-level redirect resolves the share path
to the in-app route via `ShareLinks.routeFor`.

**App installed, link opened inside WhatsApp on Android.** WhatsApp uses an
embedded browser, and an embedded browser never triggers App Link
verification. This is a large share of real taps. The landing page renders, and
its «افتحي في تطبيق ريم» button opens `reem://…` — the custom scheme, which is
why that scheme is still registered alongside the App Links.

**App not installed.** The landing page is the destination: the photograph, the
name, the price, the boutique, and a link to the store. Open Graph tags are
rendered server-side, so WhatsApp, Telegram and Facebook draw a proper preview
card without running a line of script.

**A dead or private link.** A branded 404 in Arabic saying what probably
happened, not the API's JSON error envelope. A resolver that *throws* is
distinguished from a link that resolves to nothing: the first is logged and
answers 503 with «حاولي مرّة أخرى», because telling her a product was removed
when the database merely blinked costs a sale.

## Privacy

Every resolver applies the rule a signed-out visitor gets and returns nothing
otherwise: a draft product, a followers-only post, a closed profile and an
expired story all resolve to the 404 page rather than to a preview with the
interesting parts blanked out. A messenger's crawler caches what it is given,
and a cache is not something a privacy setting can reach into afterwards.

## Configuration

Nothing below is required. With all of it unset the links still work — they
point at the API's own origin and open the landing page.

| Variable | Where | What it does |
|---|---|---|
| `SHARE_PUBLIC_ORIGIN` | API | The origin links are written with. Falls back to `MEDIA_PUBLIC_ORIGIN`, then Render's `RENDER_EXTERNAL_URL`. |
| `SHARE_BASE_URL` | Flutter `--dart-define` | The same value, on the client. Falls back to the origin of `API_BASE_URL`. |
| `ANDROID_SHA256_CERT_FINGERPRINTS` | API | Comma-separated SHA-256 signing fingerprints. Until set, `assetlinks.json` is `[]` and Android does not verify. |
| `IOS_APP_IDS` | API | `TEAMID.shop.reem.app`. Until set, the Apple association is empty and iOS claims nothing. |
| `ANDROID_STORE_URL`, `IOS_STORE_URL`, `APP_APK_URL` | API | Where the landing page sends somebody without the app. With none set it says the app is coming rather than linking to a listing that does not exist. |
| `APP_LINK_SCHEME` | API | Default `reem`. Must match `CFBundleURLSchemes` and the scheme intent-filter. |

`SHARE_PUBLIC_ORIGIN` and `SHARE_BASE_URL` must be the **same value**, or the
canonical URLs the server writes disagree with the links the app hands out.

### Attaching a custom domain

1. Point the domain at the Render service and let the certificate issue.
2. Set `SHARE_PUBLIC_ORIGIN=https://reem.shop` on the API.
3. Build the app with `--dart-define=SHARE_BASE_URL=https://reem.shop`.
4. The host is already listed in `AndroidManifest.xml` and
   `Runner.entitlements` alongside `reem-api.onrender.com`, so links already in
   circulation on the old host keep opening the app.

### Making links open the app

These are the only steps that need a keystore and an Apple team, and they are
the only part that cannot be done from this repository.

**Android.** `keytool -list -v -keystore <upload.jks>` prints the SHA-256
fingerprint. Once the app is on Play, add Play's *app signing* key fingerprint
too, from Play Console → Setup → App integrity — with only the upload key
listed, a locally-built APK verifies and a store install does not. Put both in
`ANDROID_SHA256_CERT_FINGERPRINTS`, comma-separated. Verify with:

```bash
curl -s https://reem-api.onrender.com/.well-known/assetlinks.json
```

**iOS.** Enable Associated Domains for the App ID in the Apple Developer
portal, attach `Runner.entitlements` to the Runner target in Xcode (Signing &
Capabilities), and set `IOS_APP_IDS` to `TEAMID.shop.reem.app`. Apple's CDN
caches the association file, so get this right *before* the first TestFlight
build goes out. Verify with:

```bash
curl -s https://reem-api.onrender.com/.well-known/apple-app-site-association
```

## What the share sheet sends

For a product: the photograph as an attached file, then the name, the price,
the boutique and the link. The picture is attached rather than linked because a
WhatsApp message carrying a photograph *is* the recommendation, where a link
preview is a card the reader has to decide to trust.

Every part is best-effort and degrades rather than blocks. The image download
is bounded at six seconds and five megabytes, the bytes are sniffed so a CDN
answering `application/octet-stream` does not send an unopenable file, and any
failure falls back to the text-and-link share. The link is always in the body,
so nothing is lost when the picture is.

Each field is dropped rather than faked: a product with no live offer is shared
without a price, not with a wrong one.

## Where the code is

```
backend/src/modules/links/
  share-links.ts           the path shapes (mirror of the Dart file)
  share-preview.ts         what a preview is
  share-preview.service.ts id → preview, one lean query per kind
  landing-page.ts          the HTML, the Open Graph tags, the escaping
  app-links.service.ts     assetlinks.json and apple-app-site-association
  links.controller.ts      the routes, the CSP, the 404 and 503 pages
  links.spec.ts            34 tests

lib/core/shared/services/
  share_links.dart         the path shapes (mirror of the TS file)
  share_service.dart       the share sheet, the image, the message body

test/share_links_test.dart          the shapes, both directions
test/share_link_routing_test.dart   a link followed to a real screen
```

`LinksModule` is registered **last** in `AppModule`. Its routes carry no
controller prefix — `/product/:id`, `/p/:id`, `/user/:id`, `/` — so every JSON
endpoint is matched first and a landing page can never shadow one. The singular
`/product/:id` is the share path for the same reason: `/products/:id` is the
catalogue API.
