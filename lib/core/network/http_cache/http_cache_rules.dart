import 'package:reem/core/data/cache/cache_policy.dart';

/// What may be cached, and for how long.
///
/// The default is **not to cache**. A GET only earns an entry by being listed
/// here, because the cost of a wrong entry is not a slow screen — it is a
/// screen showing something that is no longer true. Anything that moves with
/// money, stock or a conversation is left off the list on purpose.
abstract final class HttpCacheRules {
  /// Longest-prefix wins, so `/products/trending` can differ from `/products`.
  static const Map<String, CachePolicy> _byPrefix = {
    // ── The catalogue ────────────────────────────────────────────────────
    // Slow-moving and read constantly. A product she opened five minutes ago
    // should paint instantly when she comes back to it from the cart.
    '/products': CachePolicy(
      strategy: CacheStrategy.staleWhileRevalidate,
      ttl: Duration(minutes: 5),
    ),
    '/categories': CachePolicy(
      strategy: CacheStrategy.staleWhileRevalidate,
      ttl: Duration(hours: 12),
    ),

    // ── Discovery ────────────────────────────────────────────────────────
    // The home feed is the first thing she sees on a cold start. Serving the
    // last one immediately and refreshing behind it is the difference between
    // an app that opens and an app that loads.
    '/discovery': CachePolicy(
      strategy: CacheStrategy.staleWhileRevalidate,
      ttl: Duration(minutes: 3),
    ),
    '/posts/feed': CachePolicy(
      strategy: CacheStrategy.staleWhileRevalidate,
      ttl: Duration(minutes: 2),
    ),
    '/stories': CachePolicy(
      strategy: CacheStrategy.staleWhileRevalidate,
      ttl: Duration(minutes: 2),
    ),

    // ── Search scaffolding ───────────────────────────────────────────────
    // Suggestions and trending terms; not results, which follow the query.
    '/search/trending': CachePolicy(
      strategy: CacheStrategy.staleWhileRevalidate,
      ttl: Duration(minutes: 30),
    ),
    '/search/suggestions': CachePolicy(
      strategy: CacheStrategy.staleWhileRevalidate,
      ttl: Duration(minutes: 10),
    ),

    // ── Reference data ───────────────────────────────────────────────────
    // Governorates and payment methods change a few times a year. Caching
    // them for a day also means checkout still opens on a dead connection.
    '/delivery/governorates': CachePolicy(
      strategy: CacheStrategy.cacheFirst,
      ttl: Duration(days: 1),
    ),
    '/payments/methods': CachePolicy(
      strategy: CacheStrategy.cacheFirst,
      ttl: Duration(hours: 12),
    ),

    // ── Identity ─────────────────────────────────────────────────────────
    // Short TTL: it is her own profile, so a stale paint is acceptable for
    // seconds, not minutes.
    '/users/me': CachePolicy(
      strategy: CacheStrategy.staleWhileRevalidate,
      ttl: Duration(minutes: 1),
    ),
    '/experience/me': CachePolicy(
      strategy: CacheStrategy.staleWhileRevalidate,
      ttl: Duration(minutes: 5),
    ),

    // ── Policies ─────────────────────────────────────────────────────────
    // The terms change a few times a year and are read at the worst possible
    // moments — mid-checkout, mid-dispute, on a train. Cache-first means the
    // returns policy opens on a dead connection, which is exactly when
    // somebody needs to read it. The key carries `?locale`, so the Arabic and
    // English texts are separate entries rather than one that flips.
    //
    // `/policies/pending` and `/policies/acceptances` are excluded below: one
    // decides whether the app is usable, and the other is a legal receipt.
    // Neither may ever be answered from yesterday.
    '/policies': CachePolicy(
      strategy: CacheStrategy.cacheFirst,
      ttl: Duration(hours: 6),
    ),
  };

  /// Prefixes that must never be cached even though a broader rule covers
  /// them. Longest-prefix matching would otherwise let `/products` cache a
  /// seller's stock edits.
  static const List<String> _never = [
    '/cart',
    '/orders',
    '/payments/', // the catalogue at `/payments/methods` is allowed above
    '/chats',
    '/auth',
    '/seller/',
    '/admin/',
    '/notifications',
    '/wallet',
    '/returns',
    '/disputes',
    // Her own likes and picks, answered now. Under `/products` by path, but a
    // heart painted from a five-minute-old cache is a heart that lies.
    '/products/engagement',
    // The consent gate reads the first of these on every launch and blocks the
    // app on the answer; the second is the record of what she agreed to. A
    // stale answer to either is a bug with legal weight, not a slow screen.
    '/policies/pending',
    '/policies/acceptances',
  ];

  /// The policy for [path], or null when this GET must go to the network.
  static CachePolicy? policyFor(String path) {
    final normalised = _stripQuery(path);

    for (final blocked in _never) {
      if (normalised == blocked || normalised.startsWith(blocked)) {
        // `/payments/methods` is explicitly allowed; the blanket `/payments/`
        // rule exists to keep every other payment route off the disk.
        if (_byPrefix.containsKey(normalised)) break;
        return null;
      }
    }

    String? best;
    for (final prefix in _byPrefix.keys) {
      if (normalised == prefix || normalised.startsWith('$prefix/')) {
        if (best == null || prefix.length > best.length) best = prefix;
      }
    }
    return best == null ? null : _byPrefix[best];
  }

  /// The read prefixes a write to [path] makes untrue.
  ///
  /// Deliberately blunt: after a favourite is toggled, every discovery and
  /// product read is retired. A cache that is slightly too eager to forget is
  /// a performance question; one that is too eager to remember is a bug.
  static List<String> invalidationPrefixesFor(String path) {
    final normalised = _stripQuery(path);
    if (normalised.startsWith('/favorites')) {
      return const ['/favorites', '/products', '/discovery', '/users/me'];
    }
    if (normalised.startsWith('/posts')) {
      return const ['/posts', '/discovery'];
    }
    if (normalised.startsWith('/stories')) {
      return const ['/stories', '/discovery'];
    }
    if (normalised.startsWith('/content')) {
      // The platform behind the legacy adapters: a hide, a mute, a reshare or
      // a new post changes what `/posts/feed` and `/stories` answer too, and
      // without this a post she marked «غير مهتمة» came back from the cache on
      // the next pull.
      return const ['/content', '/posts', '/stories', '/discovery'];
    }
    if (normalised.startsWith('/users/me/profile-visibility')) {
      return const ['/users', '/content', '/search'];
    }
    if (normalised.startsWith('/seller/products') ||
        normalised.startsWith('/seller/offers')) {
      return const ['/products', '/discovery', '/search'];
    }
    if (normalised.startsWith('/users/me') || normalised.startsWith('/auth')) {
      return const ['/users/me', '/experience/me'];
    }
    // An unrecognised write invalidates the segment it addresses, which is the
    // safe default: better a needless refetch than a lie on screen.
    final firstSegment = normalised.split('/').where((s) => s.isNotEmpty);
    return firstSegment.isEmpty ? const [] : ['/${firstSegment.first}'];
  }

  static String _stripQuery(String path) {
    final index = path.indexOf('?');
    return index == -1 ? path : path.substring(0, index);
  }
}
