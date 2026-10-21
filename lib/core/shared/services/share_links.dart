import 'package:reem/core/config/app_env.dart';

/// The shapes a Reem link can take — the Dart half of a contract the server
/// holds the other half of (`backend/src/modules/links/share-links.ts`).
///
/// Every shareable thing has three addresses built from one path:
///
///   web    `https://<origin>/product/<id>`   — what is pasted into WhatsApp
///   app    `/product/<id>`                   — what the OS hands GoRouter
///   scheme `reem://product-details?id=<id>`  — the landing page's fallback
///
/// Before this, the link shapes were string literals at the call sites
/// (`'${shareBaseUrl}/p/$postId'` in one place, `/product/$id` in another) and
/// nothing anywhere resolved either of them: the app had no route for a link it
/// handed out, and the server had never heard of one. A shared product opened
/// an error page even for a woman who had Reem installed.
///
/// ## Adding a kind
///
/// Add it to [ShareLinkKind], give it a path in [_paths] and a route in
/// [routeFor], and mirror all three on the server. Sellers, stories, outfits
/// and saved collections are all just more entries.
enum ShareLinkKind {
  product,
  content,
  profile,
  storefront,
  collection,
  roomInvite,
  referral,
  /// الصالونات والجمال. Carries the salon's *slug*, so a link
  /// forwarded on WhatsApp reads as a name rather than as a UUID.
  salon,
}

/// Path patterns, in the `:param` spelling both GoRouter and Nest use.
const Map<ShareLinkKind, String> _paths = {
  ShareLinkKind.product: '/product/:id',
  ShareLinkKind.content: '/p/:id',
  ShareLinkKind.profile: '/user/:id',
  ShareLinkKind.storefront: '/user/:id/products',
  ShareLinkKind.collection: '/collection/:key',
  ShareLinkKind.roomInvite: '/rooms/join/:slug',
  ShareLinkKind.referral: '/invite/:code',
  ShareLinkKind.salon: '/salons/:id',
};

abstract final class ShareLinks {
  /// The canonical public path — `/product/abc`.
  static String path(ShareLinkKind kind, String value) {
    return _paths[kind]!.replaceFirst(
      RegExp(r':[A-Za-z][A-Za-z0-9_]*'),
      Uri.encodeComponent(value),
    );
  }

  /// The address that leaves the phone.
  static String url(ShareLinkKind kind, String value) =>
      '${AppEnv.shareBaseUrl}${path(kind, value)}';

  static String product(String id) => url(ShareLinkKind.product, id);
  static String content(String id) => url(ShareLinkKind.content, id);
  static String profile(String userId) => url(ShareLinkKind.profile, userId);
  static String storefront(String sellerId) =>
      url(ShareLinkKind.storefront, sellerId);
  static String collection(String key) => url(ShareLinkKind.collection, key);
  static String roomInvite(String slug) => url(ShareLinkKind.roomInvite, slug);
  static String referral(String code) => url(ShareLinkKind.referral, code);

  /// Takes a slug in preference to an id — `…/salons/salwn-lma` rather than
  /// `…/salons/3f2504e0-…`. The server resolves either.
  static String salon(String idOrSlug) => url(ShareLinkKind.salon, idOrSlug);

  /// The in-app route a share path opens, or null when [location] is not one.
  ///
  /// This is what makes an App Link work. Android and iOS hand the app the
  /// *path* of the URL that was tapped — `/product/abc` — and GoRouter has no
  /// such route: the product page has always been `/product-details?id=…`, and
  /// content `/content/:id`. Those spellings are kept rather than renamed,
  /// because every stored push `deep_link` and every in-app `context.push` uses
  /// them; the share paths redirect onto them instead.
  ///
  /// Matching is segment-wise on purpose. `'/product-details'.startsWith(
  /// '/product')` is true, and a prefix test here would have caught the app's
  /// own product route and bounced it back to itself for ever.
  static String? routeFor(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;
    final head = segments.first;
    final query = uri.query.isEmpty ? '' : '?${uri.query}';

    // The three whose route is not their path.
    if (head == 'product' && segments.length == 2) {
      // The id rides as a query parameter, so it is rebuilt rather than
      // passed through.
      return '/product-details?id=${Uri.encodeComponent(segments[1])}';
    }
    if (head == 'p' && segments.length == 2) {
      return '/content/${Uri.encodeComponent(segments[1])}';
    }
    if (head == 'u' && segments.length == 2) {
      // The short form of a profile link, canonicalised on arrival.
      return '/user/${Uri.encodeComponent(segments[1])}';
    }

    // The rest are already routes. Returned as-is so a caller has one uniform
    // answer — "this is a share link, open this" — rather than a null it has
    // to interpret.
    final passthrough =
        // A salon page, by id or by slug. Two segments exactly: `/salons` on
        // its own is the directory, which the app also routes.
        (head == 'salons' && segments.length <= 2) ||
        (head == 'user' && segments.length == 2) ||
        (head == 'user' && segments.length == 3 && segments[2] == 'products') ||
        (head == 'content' && segments.length == 2) ||
        (head == 'collection' && segments.length == 2) ||
        (head == 'rooms' && segments.length == 3 && segments[1] == 'join');

    return passthrough ? '${uri.path}$query' : null;
  }

  /// True when this path is one the app claims from the browser.
  ///
  /// Kept in step with the `android:pathPrefix` entries in `AndroidManifest`
  /// and the `components` in `apple-app-site-association`. Deliberately false
  /// for `/invite/:code`: an invitation is sent to somebody who does *not* have
  /// Reem, so having the app swallow it would hide the download button from the
  /// one person it was written for.
  static bool isAppHandled(Uri uri) => routeFor(uri) != null;
}
