import { occasionLabel, slotLabel } from '../ai-stylist/understanding/stylist-lexicon';
import type { OutfitSlot } from '@prisma/client';
import type { Opportunity } from './intelligence/market-intelligence.service';
import type { LifeReading } from './kernel/lifecycle';

/**
 * The wire shape of Reem Market Evolution.
 *
 * Same contract as the rest of Reem: snake_case out, Decimals as numbers,
 * Arabic rendered here rather than in the client. The last of those is the one
 * that matters — every label on these screens is derived from the same lexicon
 * the stylist and the closet reason in, so a slot cannot be called one thing
 * in a bundle and another in a room.
 */

const num = (value: unknown): number => Number(value ?? 0);
const iso = (value: Date | null | undefined): string | null =>
  value ? value.toISOString() : null;

// ── Drops ───────────────────────────────────────────────────────────────

export function serializeDrop(
  drop: {
    id: string;
    title: string;
    note: string | null;
    status: string;
    audience: string;
    startsAt: Date;
    earlyAccessAt: Date | null;
    endsAt: Date | null;
    sellerId: string | null;
    products?: Array<{
      productId: string;
      position: number;
      product?: {
        id: string;
        title: string;
        minPriceSyp: unknown;
        media?: Array<{ url: string; blurHash?: string | null }>;
      } | null;
    }>;
  },
  extras: {
    /** Set when the viewer was invited — the drop is then addressed to her. */
    invite?: { affinity: number; reasons: unknown; openedAt: Date | null } | null;
    /** True while only the invited can enter. */
    earlyAccessOnly?: boolean;
  } = {},
) {
  return {
    id: drop.id,
    title: drop.title,
    note: drop.note,
    status: drop.status,
    audience: drop.audience,
    starts_at: drop.startsAt.toISOString(),
    early_access_at: iso(drop.earlyAccessAt),
    ends_at: iso(drop.endsAt),
    seller_id: drop.sellerId,
    early_access_only: extras.earlyAccessOnly ?? false,
    // Why she is seeing it. The graph's reasons, carried all the way to the
    // screen — an invitation that cannot explain itself is a blast.
    invitation: extras.invite
      ? {
          affinity: extras.invite.affinity,
          reasons: extras.invite.reasons,
          seen: extras.invite.openedAt !== null,
        }
      : null,
    products: (drop.products ?? [])
      .sort((a, b) => a.position - b.position)
      .map((entry) => ({
        product_id: entry.productId,
        title: entry.product?.title ?? null,
        min_price_syp: entry.product ? num(entry.product.minPriceSyp) : null,
        image_url: entry.product?.media?.[0]?.url ?? null,
        blur_hash: entry.product?.media?.[0]?.blurHash ?? null,
      })),
  };
}

export function serializeDropPerformance(performance: {
  invited: number;
  notified: number;
  opened: number;
  converted: number;
  precision: number;
  conversion: number;
  affinityLift: number | null;
}) {
  return {
    invited: performance.invited,
    notified: performance.notified,
    opened: performance.opened,
    converted: performance.converted,
    precision: performance.precision,
    conversion: performance.conversion,
    // Null, not zero. No buyers means no comparison, and a zero here would
    // read as "the targeting failed" when it means "nothing to compare".
    affinity_lift: performance.affinityLift,
  };
}

// ── Bundles ─────────────────────────────────────────────────────────────

export function serializeBundle(bundle: {
  id: string;
  title: string;
  occasion: string | null;
  totalSyp: unknown;
  sellerCount: number;
  score: number;
  slots: string[];
  items: Array<{
    productId: string;
    offerId: string | null;
    slot: string | null;
    reason: string | null;
    product: {
      id: string;
      title: string;
      media?: Array<{ url: string }>;
    };
    offer?: {
      priceSyp: unknown;
      seller?: { id: string; name: string };
    } | null;
  }>;
}) {
  return {
    id: bundle.id,
    title: bundle.title,
    occasion: bundle.occasion,
    occasion_label: occasionLabel(bundle.occasion),
    total_syp: num(bundle.totalSyp),
    seller_count: bundle.sellerCount,
    score: Math.round(bundle.score),
    slots: bundle.slots,
    items: bundle.items.map((item) => ({
      product_id: item.productId,
      offer_id: item.offerId,
      title: item.product.title,
      image_url: item.product.media?.[0]?.url ?? null,
      slot: item.slot,
      slot_label: item.slot ? slotLabel(item.slot as OutfitSlot) : null,
      price_syp: item.offer ? num(item.offer.priceSyp) : null,
      seller: item.offer?.seller
        ? { id: item.offer.seller.id, name: item.offer.seller.name }
        : null,
      // The sentence that makes it a bundle rather than a gift basket.
      reason: item.reason,
    })),
  };
}

export function serializeBundleAlternatives(
  alternatives: Array<{
    slot: string | null;
    current: { productId: string; title: string; priceSyp: number };
    alternative: { productId: string; title: string; priceSyp: number };
    savingSyp: number;
  }>,
) {
  return alternatives.map((entry) => ({
    slot: entry.slot,
    slot_label: entry.slot ? slotLabel(entry.slot as OutfitSlot) : null,
    current: {
      product_id: entry.current.productId,
      title: entry.current.title,
      price_syp: entry.current.priceSyp,
    },
    alternative: {
      product_id: entry.alternative.productId,
      title: entry.alternative.title,
      price_syp: entry.alternative.priceSyp,
    },
    saving_syp: entry.savingSyp,
  }));
}

// ── Life cycle ──────────────────────────────────────────────────────────

export function serializeLifeReading(reading: LifeReading) {
  return {
    rotation: reading.rotation,
    disposition: reading.disposition,
    reason: reading.reason,
    cost_per_wear_syp: reading.costPerWear,
    confidence: reading.confidence,
    care: reading.care.map((note) => ({ code: note.code, text: note.text })),
  };
}

export function serializeWardrobeRow(row: {
  item: {
    id: string;
    title: string;
    slot: string;
    imageUrl: string | null;
    blurHash: string | null;
    wearCount: number;
    lastWornAt: Date | null;
    purchasePriceSyp: unknown;
    productId: string | null;
    resaleListing?: { id: string; status: string } | null;
  };
  reading: LifeReading;
  styleWith?: Array<{ id: string; title: string }>;
  suggestedPriceSyp?: number | null;
}) {
  return {
    closet_item_id: row.item.id,
    title: row.item.title,
    slot: row.item.slot,
    slot_label: slotLabel(row.item.slot as OutfitSlot),
    image_url: row.item.imageUrl,
    blur_hash: row.item.blurHash,
    wear_count: row.item.wearCount,
    last_worn_at: iso(row.item.lastWornAt),
    purchase_price_syp: row.item.purchasePriceSyp
      ? num(row.item.purchasePriceSyp)
      : null,
    product_id: row.item.productId,
    reading: serializeLifeReading(row.reading),
    style_with: (row.styleWith ?? []).map((product) => ({
      product_id: product.id,
      title: product.title,
    })),
    suggested_price_syp: row.suggestedPriceSyp ?? null,
    listing: row.item.resaleListing
      ? { id: row.item.resaleListing.id, status: row.item.resaleListing.status }
      : null,
  };
}

// ── Resale ──────────────────────────────────────────────────────────────

export function serializeResaleListing(
  listing: {
    id: string;
    title: string;
    note: string | null;
    condition: string;
    status: string;
    priceSyp: unknown;
    originalPriceSyp: unknown;
    listedAt: Date | null;
    soldAt: Date | null;
    closetItem?: {
      id: string;
      slot?: string;
      imageUrl: string | null;
      blurHash: string | null;
      colours?: string[];
      size?: string | null;
      brandName?: string | null;
      wearCount?: number;
    } | null;
    seller?: { id: string; name: string } | null;
    product?: { id: string; title: string } | null;
  },
  savingBps: number | null = null,
) {
  const price = num(listing.priceSyp);
  const original = listing.originalPriceSyp ? num(listing.originalPriceSyp) : null;
  // Derived here rather than only on the market read, so a listing carries its
  // discount everywhere it appears — the caller may still pass one in.
  const saving =
    savingBps ??
    (original && original > price
      ? Math.round(((original - price) / original) * 10000)
      : null);

  return {
    id: listing.id,
    title: listing.title,
    note: listing.note,
    condition: listing.condition,
    status: listing.status,
    price_syp: price,
    original_price_syp: original,
    saving_bps: saving,
    listed_at: iso(listing.listedAt),
    sold_at: iso(listing.soldAt),
    image_url: listing.closetItem?.imageUrl ?? null,
    blur_hash: listing.closetItem?.blurHash ?? null,
    slot: listing.closetItem?.slot ?? null,
    slot_label: listing.closetItem?.slot
      ? slotLabel(listing.closetItem.slot as OutfitSlot)
      : null,
    colours: listing.closetItem?.colours ?? [],
    size: listing.closetItem?.size ?? null,
    brand_name: listing.closetItem?.brandName ?? null,
    // How many times she wore it. The single most useful honest fact about a
    // second-hand garment, and the one a marketplace normally hides.
    wear_count: listing.closetItem?.wearCount ?? null,
    seller: listing.seller
      ? { id: listing.seller.id, name: listing.seller.name }
      : null,
    product_id: listing.product?.id ?? null,
  };
}

// ── Missions ────────────────────────────────────────────────────────────

export function serializeMission(row: {
  mission: {
    key: string;
    kind: string;
    titleAr: string;
    bodyAr: string;
  };
  progress: {
    status: string;
    offeredAt: Date;
    expiresAt: Date | null;
    completedAt: Date | null;
  };
  criteria: { target: number };
  reading: { progress: number; complete: boolean; remaining: number };
  evidence: { done: number; possible: number; baseline?: number };
}) {
  return {
    key: row.mission.key,
    kind: row.mission.kind,
    title: row.mission.titleAr,
    body: row.mission.bodyAr,
    status: row.progress.status,
    progress: row.reading.progress,
    remaining: row.reading.remaining,
    // The counts behind the bar, so it can be checked rather than believed —
    // and `done` is what she has done *since being asked*, not the lifetime
    // total the evidence carries. Sending the raw count beside a bar that
    // measures the difference is how a screen ends up saying "15 done, 2 to
    // go, 0%".
    done: Math.max(0, row.evidence.done - (row.evidence.baseline ?? 0)),
    target: row.criteria.target,
    possible: row.evidence.possible,
    offered_at: row.progress.offeredAt.toISOString(),
    expires_at: iso(row.progress.expiresAt),
    completed_at: iso(row.progress.completedAt),
  };
}

// ── Market intelligence ─────────────────────────────────────────────────

export function serializeOpportunity(opportunity: Opportunity) {
  return {
    code: opportunity.code,
    subject_type: opportunity.subjectType,
    subject_id: opportunity.subjectId,
    subject_name: opportunity.subjectName,
    strength: Math.round(opportunity.strength),
    confidence: opportunity.confidence,
    headline: opportunity.headline,
    action: opportunity.action,
    evidence: opportunity.evidence,
  };
}
