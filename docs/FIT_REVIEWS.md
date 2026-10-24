# «تقييمات من بمقاسي»

Reviews from women her size. Before she trusts a review of a dress, a woman
asks whether it was written by someone like her: a five-star "fits perfectly"
from a woman a head taller tells her nothing.

So a product review can now say:

- **how it fit**: runs small, true to size, or runs large;
- **the size that shipped**, read from her delivered order, never typed;
- **the reviewer's height band and usual size**, only if she agrees;
- and carry **up to four photographs** of the piece on her.

The product page then shows a fit summary, and two filters: «من بمقاسي»
(women her size) and «مع صور» (with photos).

---

## What it is made of

### On the server

Migration `20261024090000_fit_reviews`. Purely additive.

| Change | What it holds |
| --- | --- |
| `fit_profiles` (new) | «مقاساتي»: `height_cm` (130–200), `usual_size`, `share_on_reviews` |
| `product_reviews.fit` | `RUNS_SMALL` / `TRUE_TO_SIZE` / `RUNS_LARGE`, or null |
| `product_reviews.size_bought` | The size of the delivered variant |
| `product_reviews.height_band` | Her height rounded down to 5 cm (160 = 160–164) |
| `product_reviews.usual_size` | Her usual size at the time |
| `product_reviews.photo_urls` | Up to four uploads of purpose `review` |

Code lives in `backend/src/modules/reputation/`:

| File | Responsibility |
| --- | --- |
| `fit/fit-reviews.ts` | Pure. Height bands, allowed sizes, who counts as "near", the fit tally and its floor, the suggested size |
| `fit/fit-profile.service.ts` | Reading and saving «مقاساتي» |
| `fit/fit-profile.controller.ts` | `GET` / `PUT /fit-profile` |
| `reputation.service.ts` | Writes the fit facts on a review; the filters; `productFit` |

A new media purpose, `review`, is public and accepts images only.

### On the client

| File | What it is |
| --- | --- |
| `reputation/presentation/screens/fit_profile_screen.dart` | «مقاساتي», at `/fit-profile`. Linked from the profile menu, beside her reviews |
| `reputation/presentation/widgets/product_fit_panel.dart` | The fit summary on a product page |
| `reputation/presentation/widgets/review_composer.dart` | Gains the fit question, photos, and the share switch (product reviews only) |
| `reputation/presentation/widgets/review_card.dart` | Shows the fit facts as chips and the photos as a strip |
| `product_details/presentation/widgets/product_reviews_section.dart` | The panel, the three filter chips, and an empty state per filter |

---

## Privacy is the design

- **Two facts, nothing more.** No weight, no body shape, no measurements.
  Those are what make a size form feel like an examination, and height plus
  usual size are enough to answer "did it fit someone like me".
- **The profile has one reader: her.** There is no route that serves another
  woman's profile.
- **What others see is a snapshot, and a coarse one.** A review copies her
  height as a 5 cm band and her usual size, and only when she agrees: either
  her profile's standing choice or a switch on that one review. Editing her
  profile later does not rewrite old reviews.
- **The exact height never leaves the server** on someone else's screen. The
  serializer sends the band as a label (`"160–164"`), never a number.
- **Photos are public, and she is told so before she adds them**, with a hint
  that she can leave her face out. They are published only when the review is
  approved.
- **Deleting her account takes her body off her reviews.** The review text
  stays under «حساب محذوف», as the content policy says. But her photographs,
  height band and usual size are removed from every review she wrote, and her
  fit profile is deleted. How the piece fit, and the size that shipped, are
  about the product and remain.

---

## The size is the one that shipped

`size_bought` is read from the variant of the delivered order the review is
attached to. A review that says "true to size" is only useful beside the size
it was true of, and that has to be the size that actually arrived.

If the order held the piece **in two sizes**, no size is recorded. That is the
try-both-keep-one habit, and the review cannot say which one she kept. No size
is better than the wrong one.

---

## Who counts as "my size"

`isNearMe` compares **only what both sides said**:

- **Size:** her usual size against the reviewer's usual size *or* the size
  the reviewer received. The second is often more useful: an M who bought the
  L "because it runs small" is exactly the review an M wants to read.
- **Height:** the middle of the reviewer's band within 6 cm of hers.

A reviewer matches when at least one dimension was compared and all compared
ones agree. A review with no body attached never matches. "From someone like
me" must not include someone unknown.

---

## The summary has a floor

- **No verdict below 3 voices.** The counts are still shown (the reviews are
  public), but no sentence like "runs small" is drawn from two women.
- **A verdict needs a majority, not a plurality.** 2 small, 2 true, 1 large is
  "opinions differ".
- **The suggested size** («البنات اللي بمقاسك أخدوا L وقالوا مضبوط») needs at
  least two women near her who called the size right, and no tie.

Only approved reviews count towards the summary.

---

## Photos cannot be anyone else's

Every `photo_urls` entry must resolve to an upload **she owns, of purpose
`review`**. Otherwise a public review could carry her private closet photo,
or another woman's picture, onto a product page. The check runs before the row
is written, so a refused photo leaves no half-saved review. Accepted photos
are claimed (`markAttached`) so the media sweeper keeps them.

---

## API

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/fit-profile` | Hers, plus the list of sizes the picker offers |
| PUT | `/fit-profile` | `{ height_cm?, usual_size?, share_on_reviews? }`; `null` clears a field |
| GET | `/reputation/products/:id/reviews` | New `filter` = `near_me` / `photos` |
| GET | `/reputation/products/:id/fit` | `{ overall, has_profile, near_me, suggested_size, photos_count }` |
| POST | `/reputation/products/:id/reviews` | New `fit?`, `photo_urls?` (≤ 4), `share_fit?` |

Every product review payload now carries `fit`, `size_bought`, `height_band`
(as a label), `usual_size` and `photos`.

---

## Testing

```bash
cd backend && npm test   # fit-reviews.spec.ts (8) + fit-reviews.integration.spec.ts (6)
flutter test test/fit_reviews_test.dart
```

---

## What is not built

- **A review moderation screen.** Reviews, photos included, are approved
  through `PATCH /reputation/admin/reviews`, which existed before this
  feature. The moderation queue (`GET /reputation/admin/moderation-queue`)
  now returns the photos and fit facts, but no screen in the app shows that
  queue yet.
- **Editing a review** to add photos later. There is no review edit route.
- **Fit facts on shop reviews.** A boutique has no size.
