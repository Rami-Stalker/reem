# Product interactions

Every product in Ohara supports **Like, Share, Save, Repost and Comments** —
without exception, and wherever it is drawn. The interactions belong to the
*product*, not to the widget showing it and not to whether it happens to be
told as a post.

## The two ways a product is shown

| Shown as | Outside the product page | Inside the product page |
|---|---|---|
| **A post** (`ProductPostCard`) | Like, Share, Save, Repost, Comments — the full action bar | everything again, same store |
| **A grid / card / rail / mosaic tile** | Like | Share, Save, Repost, Comments |

A tile gets one affordance because it has room for one, and it is the like:
the only interaction that is honest at a glance and needs no label. The other
four are one tap away, on a page that can name them.

## What was wrong

The rule was written against a real failure, and the failure had two halves.

**Coverage.** The grid had a heart. The mosaic had none. The four product
rails — «مختارة لكِ», «شوهدت مؤخراً», «قد يعجبكِ أيضاً», the wishlist
highlights — had none. Search results had none. Favourites had a *decorative*
heart that could not be pressed. Outfit pieces, closet suggestions, bundle
pieces and flash deals had none.

**State.** The one heart the grid did have wrote to
`favoritesNotifierProvider`, a different store from the
`productEngagementProvider` that the product page and the post card use. So a
piece saved from the home grid opened with an empty heart, and a piece liked on
its page came back to the grid looking untouched. That notifier's
`toggleFavorite` was also POST-only: there was no path through it that could
ever *un*-favourite anything.

And the home showcase — a widget whose own documentation promised "one set of
pieces, three ways to look at it" — rendered the content *feed* in its post
shape while rendering products in its mosaic and grid, so switching shape could
change which pieces were on the page and which object a heart belonged to.

## How it holds now

### One store

`productEngagementProvider` is the single shelf of product engagement for the
whole app, keyed by product id, rebuilt when the signed-in account changes.
Every surface reads it and every gesture writes it. The server backs it with
one batch endpoint, `GET /products/engagement/batch`, which returns all five
facts — `likes_count`, `comments_count`, `shares_count`, `picks_count`,
`is_liked`, `is_saved`, `is_picked` — for up to sixty ids at once, guest-aware.

### One gesture implementation

`ProductGestures` owns the haptic, the sign-in gate, the optimistic write and
the message on a refusal. `ProductGestures.likeById` is the single like; the
`Product`-flavoured `like()` delegates to it, so a caller holding only an id
behaves identically to one holding the whole product.

### One slot, installed once

The interaction is not a parameter each screen passes. `DsProductActions` is an
inherited scope installed by `AppChrome`, above the navigator:

```
AppChrome
└── ProductActionsScope          ← installs the builder, once
    └── Navigator
        └── …every route…
            └── ProductCardLuxe  ← asks DsProductActions.of(context, product, surface)
```

A card asks the scope for its product's interaction and positions it. With no
scope installed — a widget preview, a golden, the design-system sandbox — the
lookup returns null and the card draws exactly what it drew before. Nothing
here is required for a card to render.

This is what makes «أي مكان مستقبلي يعرض Product» true rather than aspirational:
a grid written next year inherits the interactions without its author knowing
the scope exists.

### Seeding is automatic

`ProductLikeButton` seeds the shared store as it builds. A grid of forty tiles
queues forty ids, and the notifier's 60 ms window collapses them into one
request. No screen has to remember to load engagement.

## Surfaces

| Surface | Shape | Carries |
|---|---|---|
| Home showcase | shelf (3 shapes) | all five as posts, like as tile |
| Department / category / "see all" | shelf (3 shapes) | same |
| A boutique's page, her picks | shelf (3 shapes) | same |
| Search results | `DsProductCard` | like |
| Favourites | `FavoriteProductCard` | like (the save is the shelf itself) |
| Product rails (recommended, recently viewed, related, wishlist, visually similar) | `ProductCardCompact` | like |
| Flash deals | bespoke card | like |
| Outfits «التنسيقات» | piece row | like |
| Closet gap suggestions | suggestion card | like |
| Bundle pieces | projection, by id | like |
| Visual-search matches | `DsProductCard` | like, which is also the ranker's feedback |
| Product page | `ProductSocialBar` | all five |

Two deliberate omissions:

- **A tagged product inside a content post** (the "shop this" plate) is a
  citation, not a catalogue tile. The post's own heart is already on the card
  and a second one on the plate would be two hearts meaning two things.
- **The seller console's top-products list** is an analytics projection with
  sales figures, not a shopping surface. A seller liking her own listing from
  her dashboard is not an interaction anyone asked for.

## Save, and the two hearts problem

Because the catalogue tile's heart is now the public **like**, the product
page's gallery control — which is **save**, «المفضّلة» — is drawn as a
bookmark, matching the bookmark in the post action bar below it. One product
never shows two hearts that mean different things.

`ProductGestures.save()` sends the explicit POST or DELETE and then reloads
`favoritesNotifierProvider`, so the favourites shelf is still filled and
emptied exactly as before.

## Adding a surface

If the surface uses `SliverProductGrid`, `SliverProductMosaic`, `ProductRail`
or `SliverProductShelf`, there is nothing to do.

If it draws its own card and holds a `Product`:

```dart
if (DsProductActions.of(context, product, DsProductSurface.tile)
    case final action?)
  PositionedDirectional(top: 8, end: 8, child: action),
```

If it holds only a product id — a bundle piece, a drop item, any projection:

```dart
ProductLikeButton.forId(item.productId, compact: true, showCount: false)
```

Use `DsProductSurface.rail` for anything at rail density; it drops the count
and shrinks the target.

> **RTL:** position with `PositionedDirectional` and `end:`, never `Positioned`
> and `right:`. A discount badge pinned to the physical left sits on the *end*
> side in Arabic, which is where the interaction goes — the rail card had
> exactly this collision.

## Where the code is

```
lib/core/design_system/patterns/product_actions.dart   the slot (no providers)
lib/features/product_social/
  presentation/product_gestures.dart                   the one implementation
  presentation/providers/product_social_providers.dart the one store
  presentation/widgets/product_actions_scope.dart      installs the slot
  presentation/widgets/product_like_button.dart        the live heart
  presentation/widgets/product_shelf.dart              the three shapes, once
  presentation/widgets/product_post_card.dart          all five, as a post
  presentation/widgets/product_social_bar.dart         all five, on the page

backend/src/modules/product-social/                    likes, picks, shares,
                                                       comments, batch read

test/product_interactions_test.dart                    15 tests
test/product_interactions_visual_preview_test.dart     PNGs of every shape
```
