import { ShareLinkKind } from './share-links';

/**
 * What a shared thing looks like to somebody who is not inside the app.
 *
 * One shape for every kind, because the two consumers — the Open Graph tags a
 * messenger reads and the HTML a browser draws — want exactly the same facts
 * and would otherwise each grow their own per-kind switch.
 *
 * Everything here is already public. The resolvers refuse anything that is
 * not: a draft product, a followers-only post, a closed profile and an expired
 * story all come back as `null` rather than as a preview with the interesting
 * parts blanked out, because a link preview is rendered by a third party's
 * crawler and there is no undoing what it caches.
 */
export interface SharePreview {
  kind: ShareLinkKind;
  /** Canonical share path, e.g. `/product/<id>` — never the alias. */
  path: string;
  /** In-app route, e.g. `/product-details?id=<id>`. */
  appRoute: string;

  /** `og:title` and the page's headline. */
  title: string;
  /** `og:description`. Trimmed to something a messenger will actually show. */
  description: string;
  /** Absolute https URL, or null when the thing genuinely has no picture. */
  imageUrl: string | null;
  /** Portrait media (a story, a reel) previews better when it is declared. */
  imageIsPortrait?: boolean;

  /** The eyebrow above the headline: «منتج», «منشور», «بائعة». */
  label: string;

  /** Formatted, ready to print — `145,000 ل.س`. Null when nothing is priced. */
  price?: string | null;
  /** The struck-through original, when there is one. */
  compareAtPrice?: string | null;
  /**
   * The same figure unformatted, for `schema.org` and the `product:price:*`
   * Open Graph pair. Facebook and Google both parse these; neither can read
   * `145,000 ل.س`.
   */
  priceAmount?: string | null;
  priceCurrency?: string | null;
  /** Who is behind it — a boutique, an author, an inviter. */
  byline?: string | null;
  bylineImageUrl?: string | null;

  /** Small facts printed under the headline: rating, stock, follower count. */
  facts?: { label: string; value: string }[];

  /** A short body — a caption, a bio, a note. */
  body?: string | null;

  /** True when the thing exists but can no longer be had (sold out, expired). */
  unavailableNote?: string | null;
}
