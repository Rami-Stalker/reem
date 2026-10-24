import {
  Prisma,
  VisualSearchRegion,
  VisualSearchSession,
  VisualTryOnRequest,
} from '@prisma/client';
import { ProductRecord, defaultOffer } from '../../common/catalog/product-include';
import { Money } from '../../common/money';
import { serializeProduct } from '../../common/serializers/product.serializer';
import { serializeStylistBrief } from '../ai-stylist/ai-stylist.serializer';
import { slotLabel } from '../ai-stylist/understanding/stylist-lexicon';
import { StyleBrief } from '../ai-stylist/understanding/style-brief';
import { ScoredVisualMatch } from './search/visual-ranker';
import { VisualSearchView } from './search/visual-search.service';
import {
  FRAMING_LABELS,
  PATTERN_LABELS,
  TONE_LABELS,
  VisualAttributes,
  attributesToChips,
} from './understanding/visual-attributes';
import { TryOnCapability } from './try-on/visual-try-on.service';

/**
 * The wire shape of Ohara Visual Shopping.
 *
 * `snake_case` throughout, money as `{ amount, currency }`, products through
 * the shared `serializeProduct` — the same three rules the rest of the API
 * follows, so a card from a visual search and a card from the catalogue are
 * byte-for-byte the same object and the client has one widget for both.
 *
 * The one shape worth explaining is `similarity`. It is sent as a 0–1 float
 * *and* as a rounded percentage, because those are two different jobs: the
 * float is what a client sorts and filters on, and the integer is what appears
 * on the badge. Rounding on the server means every surface — the app, a future
 * web client, an internal dashboard — shows the same number for the same
 * match, which is the sort of thing that quietly diverges when each caller
 * rounds for itself.
 */

export function serializeVisualAttributes(attributes: VisualAttributes) {
  return {
    colours: attributes.colours.map((colour) => ({
      key: colour.key,
      label: colour.labelAr,
      share: round(colour.share, 3),
    })),
    pattern: attributes.pattern,
    pattern_label: PATTERN_LABELS[attributes.pattern],
    tone: attributes.tone,
    tone_label: TONE_LABELS[attributes.tone],
    framing: attributes.framing,
    framing_label: FRAMING_LABELS[attributes.framing],
    studio_background: attributes.studioBackground,
    subject_fill: round(attributes.subjectFill, 3),
    categories: attributes.categories,
    /// Kept beside `categories` for clients that only need the identifiers.
    category_slugs: attributes.categories.map((entry) => entry.slug),
    slots: attributes.slots,
    /// Per field: `PIXELS` was measured, `NEIGHBOURS` was inferred from what
    /// the catalogue matched, `VISION` came from a model. The client labels an
    /// inference as an inference rather than asserting it.
    ///
    /// Keyed by the *wire* field name, not the internal one. Emitting
    /// `categorySlugs` into a payload where every other key is snake_case
    /// meant a client looking up `category_slugs` — the name it can see —
    /// found nothing and rendered an inference as a measurement.
    provenance: snakeKeys(attributes.provenance),
    confidence: round(attributes.confidence, 3),
    chips: attributesToChips(attributes),
  };
}

export function serializeVisualMatch(entry: {
  id: string;
  scored: ScoredVisualMatch;
}) {
  const { scored } = entry;
  const offer = defaultOffer(scored.product);

  return {
    id: entry.id,
    product: serializeProduct(scored.product as unknown as ProductRecord, {
      isLiked: false,
    }),
    offer_id: offer?.id ?? null,
    /// The image of this listing that actually matched — often not its first.
    matched_media_url: scored.match.mediaUrl || null,

    /// 0–1, and the number everything sorts by.
    similarity: round(scored.similarity, 4),
    /// The badge: "٩٤٪ مشابه".
    similarity_percent: Math.round(scored.similarity * 100),
    /// The two halves, so a card can be explained and an operator can audit a
    /// number that looks wrong.
    visual_score: round(scored.visualScore, 4),
    attribute_score: round(scored.attributeScore, 4),

    reason: scored.reason,
    reason_codes: scored.reasons,
    quoted_price: scored.product.minPriceSyp
      ? Money.of(scored.product.minPriceSyp, 'SYP').toJSON()
      : null,
  };
}

export function serializeVisualRegion(
  region: VisualSearchView['results'][number]['region'],
) {
  return {
    id: region.id,
    detector: region.detector,
    slot: region.slot,
    slot_label: region.slot ? slotLabel(region.slot as never) : null,
    label: region.label,
    /// Normalised 0–1 against the uploaded photograph, so the client can draw
    /// the box over its own copy at any size.
    box: region.box,
    /// Deliberately exposed. A `LAYOUT` band is a geometric guess and is
    /// capped well below a `VISION` detection; the client shows the weaker one
    /// as a suggestion rather than as a fact.
    confidence: round(region.confidence, 3),
  };
}

export function serializeVisualSession(
  session: VisualSearchSession & { regions?: VisualSearchRegion[] },
  extras: {
    attributes?: VisualAttributes;
    brief?: StyleBrief;
    results?: VisualSearchView['results'];
    notice?: string | null;
    queryImageUrl?: string | null;
  } = {},
) {
  return {
    id: session.id,
    status: session.status,
    source: session.source,
    /// Null once the retention clock has run. The session still answers
    /// refinements — the descriptor is not the photograph.
    query_image_url: extras.queryImageUrl ?? null,
    image_expires_at: session.imageExpiresAt?.toISOString() ?? null,
    engine: session.engine,
    latency_ms: session.latencyMs,
    refinements: refinements(session.refinements),
    refinements_count: session.refinementsCount,
    created_at: session.createdAt.toISOString(),

    ...(extras.attributes
      ? { understanding: serializeVisualAttributes(extras.attributes) }
      : {}),
    ...(extras.brief ? { brief: serializeStylistBrief(extras.brief) } : {}),
    ...(extras.results
      ? {
          regions: extras.results.map((entry) => ({
            ...serializeVisualRegion(entry.region),
            matches: entry.matches.map((match) => serializeVisualMatch(match)),
          })),
        }
      : {}),
    ...(extras.notice !== undefined ? { notice: extras.notice } : {}),
  };
}

export function serializeTryOn(
  row: VisualTryOnRequest & { product?: unknown },
  extras: { sourceImageUrl?: string | null; resultImageUrl?: string | null } = {},
) {
  return {
    id: row.id,
    product_id: row.productId,
    variant_id: row.variantId,
    offer_id: row.offerId,
    session_id: row.sessionId,
    provider: row.provider,
    status: row.status,
    /// Machine-readable and never dressed up: `NO_PROVIDER` means exactly
    /// that, and the client renders an honest sentence rather than a spinner
    /// that never resolves.
    failure_code: row.failureCode,
    consent_at: row.consentAt?.toISOString() ?? null,
    expires_at: row.expiresAt?.toISOString() ?? null,
    source_image_url: extras.sourceImageUrl ?? null,
    result_image_url: extras.resultImageUrl ?? null,
    created_at: row.createdAt.toISOString(),
  };
}

export function serializeTryOnCapability(capability: TryOnCapability) {
  return {
    available: capability.available,
    provider: capability.provider,
    message: capability.message,
    retention_hours: capability.retentionHours,
  };
}

function refinements(value: Prisma.JsonValue | null) {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) return [];
    const record = entry as Record<string, unknown>;
    const text = typeof record['text'] === 'string' ? record['text'] : null;
    return text ? [{ text, at: String(record['at'] ?? '') }] : [];
  });
}

function round(value: number, places: number): number {
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

/** `{ categorySlugs: 'NEIGHBOURS' }` → `{ category_slugs: 'NEIGHBOURS' }`. */
function snakeKeys<T>(record: Partial<Record<string, T>>): Record<string, T> {
  const out: Record<string, T> = {};
  for (const [key, value] of Object.entries(record)) {
    if (value === undefined) continue;
    out[key.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`)] = value;
  }
  return out;
}
