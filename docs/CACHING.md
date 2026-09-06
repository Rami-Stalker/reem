# Response caching

The client caches HTTP GETs. This document is the contract: what is cached,
what is deliberately not, and how to change either.

```bash
flutter test test/http_cache_test.dart
```

---

## Why it sits in the transport layer

The repository layer already had a caching design — `DataSynchronizer`,
`CachePolicy`, `MemoryCacheStore` — constructed in `core_providers.dart` and
consumed by **zero** of the thirty-five repositories. Every screen refetched on
every visit, two widgets wanting the same data made two requests, and nothing
worked offline.

Adopting it at the repository layer would have meant threading a synchronizer
through thirty-five constructors and writing a codec per entity to get anything
onto disk. Putting the cache in the Dio interceptor chain instead buys the same
thing for every repository at once, and at that layer the payload is already
JSON — which is exactly what a disk cache can store.

`DataSynchronizer` remains for the case this does not cover: caching a
*computed* result rather than a response.

---

## What is cached

`lib/core/network/http_cache/http_cache_rules.dart` is the whole policy. The
default is **not** to cache; a path earns an entry by being listed.

| Path | Strategy | TTL |
| --- | --- | --- |
| `/products`, `/categories` | stale-while-revalidate | 5 min / 12 h |
| `/discovery`, `/posts/feed`, `/stories` | stale-while-revalidate | 2–3 min |
| `/search/trending`, `/search/suggestions` | stale-while-revalidate | 10–30 min |
| `/delivery/governorates`, `/payments/methods` | cache-first | 12 h – 1 day |
| `/users/me`, `/experience/me` | stale-while-revalidate | 1–5 min |

Never cached, whatever else matches: `/cart`, `/orders`, `/payments/*` (bar the
methods catalogue), `/chats`, `/auth`, `/seller/*`, `/admin/*`,
`/notifications`, `/wallet`, `/returns`, `/disputes`.

The rule is not "is this slow" but "what is the cost of being wrong". Anything
that moves with money, stock or a conversation goes to the network every time.

### Changing it

Add a prefix to `_byPrefix`, or to `_never`. Longest prefix wins, so
`/payments/methods` can be cacheable while `/payments/` is not. Add a case to
`test/http_cache_test.dart` in the same change — the test file is the list of
things that must stay true.

A single call site can override the table:

```dart
dio.get('/anything', options: Options(extra: {
  CacheInterceptor.policyExtraKey: const CachePolicy(ttl: Duration(minutes: 5)),
}));
```

---

## What it does

**Remembers.** A read inside its TTL is served from the store, and the screen
paints without a spinner. Stale-while-revalidate paints the old answer
immediately and refreshes behind it on the same client, so the refresh still
carries its auth and device headers.

**Coalesces.** Identical GETs in flight at the same time share one round trip.
Three home-screen sections asking for the same discovery slice make one
request.

**Survives.** When a request fails with a *connection* error and a stale entry
exists, the stale entry is served. That is the app's offline reading story.

A server that answers clearly — 404, 422 — is never papered over with a stale
success. The distinction is in `_isRecoverable`.

**Forgets.** A successful write retires the reads it makes untrue;
`HttpCacheRules.invalidationPrefixesFor` maps a written path to the read
prefixes it invalidates. It is deliberately blunt — favouriting a product
retires every product and discovery read — because a cache too eager to forget
costs a request, and one too eager to remember shows a lie.

---

## Whose cache it is

Entries are keyed `scope|METHOD|path|sorted-query`. The scope is the signed-in
user's id, bound by `AuthNotifier`'s `state` setter through `SessionCache`, so
two accounts on one handset — the common case here — can never read each
other's data. Signing out clears the store outright, because a device that
changes hands should not carry the last account's feed in its cache folder.

The scope is the *user id*, not the access token: the token rotates every
fifteen minutes and would throw the cache away with it.

---

## Where it lives

Memory in front of disk (`TieredHttpCacheStore`):

* `MemoryHttpCacheStore` — bounded LRU, 200 entries. A screen visited twice in
  one session never touches the filesystem.
* `FileHttpCacheStore` — one small JSON file per entry under the OS cache
  directory, 400 entries, oldest evicted first. This is what makes a cold start
  paint instead of load. Writes are not awaited; a response never waits on IO
  to reach the widget that asked for it.

Every disk operation degrades to a miss rather than an exception. A corrupt
entry, a full disk or a sandboxed directory costs a network fetch, never a
crash on a screen that would otherwise have loaded.

---

## Telling her

The cache serves stale data on purpose, so the app says so. `OfflineBanner`
sits above every route in `MaterialApp.builder` and appears whenever the
handset has no connection. Cached responses also carry two headers a screen can
read if it wants to be more specific:

```dart
response.headers.value(CacheInterceptor.fromCacheHeader);   // '1' | 'coalesced'
response.headers.value(CacheInterceptor.ageHeader);         // seconds
```

Nothing reads the age header yet. A "prices as of 12 minutes ago" line on the
product page is the obvious next use for it.
