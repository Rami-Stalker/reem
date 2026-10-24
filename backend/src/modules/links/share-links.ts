/**
 * The shapes a Ohara link can take, in one place.
 *
 * Every shareable thing on this platform has exactly three addresses, and they
 * are all derived from one path:
 *
 *   web    `https://<origin>/product/<id>`   — what is pasted into WhatsApp
 *   app    `/product/<id>`                   — the route GoRouter receives
 *   scheme `reem://product-details?id=<id>`   — the landing page's fallback
 *
 * They agree because they are the same string. That is the whole point of this
 * file: the previous arrangement had the Flutter client assembling
 * `'${shareBaseUrl}/p/$postId'` by hand at one call site, `/product/$id` at
 * another, and nothing on the server that knew either shape existed — so a
 * link could not be resolved by anything, and no test could notice.
 *
 * ## Adding a kind
 *
 * Add an entry here, a resolver in `share-preview.service.ts`, a route on
 * `LinksController`, and — if the app should open it — a path pattern in the
 * two well-known files and a GoRoute on the Flutter side. Nothing else needs
 * touching; sellers, stories and outfits are all just more entries.
 */

export type ShareLinkKind =
  | 'product'
  | 'content'
  | 'profile'
  | 'storefront'
  | 'collection'
  | 'room-invite'
  | 'referral'
  /// الصالونات والجمال. Carries the slug, so a forwarded link reads as
  /// a name; the resolver accepts either.
  | 'salon';

/**
 * Path *patterns*, in Nest/GoRouter `:param` spelling.
 *
 * These are the canonical ones. Aliases (`/u/:id`) exist for brevity in a
 * message and redirect here; they are listed separately so the canonical URL
 * in the page's `<link rel="canonical">` is never the short form.
 */
export const SHARE_PATHS: Record<ShareLinkKind, string> = {
  product: '/product/:id',
  content: '/p/:id',
  profile: '/user/:id',
  storefront: '/user/:id/products',
  collection: '/collection/:key',
  'room-invite': '/rooms/join/:slug',
  referral: '/invite/:code',
  salon: '/salons/:id',
};

/**
 * Short forms, kept because they are pleasant to read in a message and because
 * `/u/:id` is what a human types from memory. Each maps onto a canonical path.
 *
 * Note which one is *not* here: `/products/:id`. That is the catalogue API —
 * `ProductsController` answers it with JSON — and an alias would have shadowed
 * a live endpoint with an HTML page depending only on module registration
 * order. The share path is the singular `/product/:id`.
 */
export const SHARE_ALIASES: Record<string, ShareLinkKind> = {
  '/u/:id': 'profile',
};

/**
 * Which kinds the app is allowed to intercept from the browser.
 *
 * Not all of them, and the omission is deliberate. A referral link is sent
 * *to somebody who does not have Ohara* — that is what an invitation is — so
 * having the app swallow it would mean the one person it was written for is
 * the one person who never sees the download button. It stays on the web.
 */
export const APP_HANDLED_KINDS: readonly ShareLinkKind[] = [
  'product',
  'content',
  'profile',
  'storefront',
  'collection',
  'room-invite',
  'salon',
];

/**
 * The in-app route a share path opens.
 *
 * Mostly the identity function — the share path *is* a route — with two
 * exceptions the app's own history explains: the product page takes its id as
 * a query parameter (`/product-details?id=…`) and content lives under
 * `/content/:id`. Both keep their old spelling so existing in-app navigation
 * and every stored push `deep_link` keep working; the share path redirects
 * onto them.
 */
export function appRouteFor(kind: ShareLinkKind, params: Record<string, string>): string {
  switch (kind) {
    case 'product':
      return `/product-details?id=${encodeURIComponent(params.id)}`;
    case 'content':
      return `/content/${encodeURIComponent(params.id)}`;
    default:
      return buildPath(SHARE_PATHS[kind], params);
  }
}

/** `/product/:id` + `{id: 'abc'}` → `/product/abc`, each value encoded once. */
export function buildPath(pattern: string, params: Record<string, string>): string {
  return pattern.replace(/:([A-Za-z][A-Za-z0-9_]*)/g, (_, name: string) => {
    const value = params[name];
    if (value === undefined) {
      throw new Error(`Missing "${name}" for share path "${pattern}"`);
    }
    return encodeURIComponent(value);
  });
}

/** The address that leaves the phone. */
export function shareUrl(
  origin: string,
  kind: ShareLinkKind,
  params: Record<string, string>,
): string {
  return `${origin.replace(/\/+$/, '')}${buildPath(SHARE_PATHS[kind], params)}`;
}

/**
 * The custom-scheme twin: `reem://product-details?id=abc`.
 *
 * Built from the *app route* rather than the share path, because this is the
 * one address that has to work without the app having been updated: it is what
 * the landing page's button uses inside a messenger's embedded browser, where
 * App Links never fire. Routing it through `appRouteFor` means an install that
 * predates the new share-path routes still lands on the right screen.
 *
 * The leading slash is dropped, which makes the first segment the URI's
 * *authority* rather than part of its path — `Uri.parse` on the Flutter side
 * hands back host `product-details` and an empty path, and `deepLinkPath` folds
 * the two back together, query string and all. That fold already existed for
 * room invites; this simply means every kind now travels through it.
 */
export function schemeUrl(
  scheme: string,
  kind: ShareLinkKind,
  params: Record<string, string>,
): string {
  return `${scheme}://${appRouteFor(kind, params).replace(/^\/+/, '')}`;
}

/**
 * The glob patterns the two platforms match on, for `assetlinks.json` and
 * `apple-app-site-association`.
 *
 * `/user/:id/products` is a prefix of `/user/:id` once both become `/user/*`,
 * so the set is deduplicated — Android in particular refuses a filter with
 * duplicate paths.
 */
export function appLinkPatterns(): string[] {
  const patterns = APP_HANDLED_KINDS.map((kind) =>
    SHARE_PATHS[kind]
      .replace(/\/:[A-Za-z][A-Za-z0-9_]*(?=\/|$)/g, '/*')
      // `/user/*/products` collapses to `/user/*`: a wildcard segment on these
      // platforms matches the rest of the path, not one segment.
      .replace(/\/\*\/.*$/, '/*'),
  );
  return [...new Set(patterns)];
}
