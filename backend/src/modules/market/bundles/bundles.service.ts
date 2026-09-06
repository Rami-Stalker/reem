import { createHash } from 'node:crypto';
import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import {
  AffinityKind,
  BundleStatus,
  OfferStatus,
  Prisma,
  ProductStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import {
  detectOccasion,
  detectSlots,
  occasionLabel,
} from '../../ai-stylist/understanding/stylist-lexicon';
import { occasionCompatible } from '../../intelligence/kernel/product-verdict';

/** Slots that make an outfit rather than a pile of clothes. */
const CORE_SLOTS = ['DRESS', 'ABAYA', 'TOP', 'BOTTOM', 'SHOES', 'BAG'];

/**
 * What a bundle is allowed to contain.
 *
 * The core slots plus the things that finish a look. Everything else — a gift
 * box, a face cream, a notebook the lexicon read as jewellery because its
 * title says «حلقات» — is excluded, and the exclusion is not fussiness. The
 * first run against real data put a newborn-reception gift and a nappy-rash
 * cream into an evening outfit, because the fallback accepted whatever slot
 * the title happened to detect. A bundle that reads as a solution has to
 * actually be one.
 */
const WEARABLE_SLOTS = [
  ...CORE_SLOTS,
  'OUTERWEAR',
  'JEWELRY',
  'ACCESSORY',
  'PERFUME',
];

/** A bundle needs at least this many pieces to be a solution. */
const MIN_ITEMS = 3;

/** And no more than this, or it stops being a suggestion. */
const MAX_ITEMS = 5;

/** Below this the pieces do not really belong together. */
const MIN_SCORE = 45;

/**
 * Assembling solutions instead of listing products.
 *
 * A bundle is built by walking the commerce graph's `COMPLEMENT` relations out
 * from a strong starting piece and taking the best partner for each empty
 * slot. That is the whole algorithm, and it is deliberately simple: the hard
 * work — deciding what complements what, and refusing the pairs that merely
 * look related — was already done when the graph was built, and redoing any of
 * it here would give Reem two opinions about the same two garments.
 *
 * ── Why bundles cross sellers ────────────────────────────────────────────
 *
 * Because outfits do. A woman assembling a wedding look buys the dress from
 * one boutique and the shoes from another, and a "bundle" restricted to one
 * shop is an upsell wearing the word. Crossing sellers is what makes this a
 * marketplace feature, and it is why the bundle reaches checkout through the
 * same door a room's purchase plan uses — that path was built for exactly this
 * shape of order.
 */
@Injectable()
export class BundlesService {
  private readonly logger = new Logger(BundlesService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Rebuild the catalogue of bundles.
   *
   * Seeded from products that anchor an outfit — a dress, an abaya — because
   * building outward from a bag produces a bag with things attached.
   */
  async build(options: { limit?: number } = {}): Promise<{ bundles: number }> {
    const anchors = await this.anchors(options.limit ?? 40);
    const built: string[] = [];

    for (const anchor of anchors) {
      const bundle = await this.assemble(anchor.id);
      if (bundle) built.push(bundle);
    }

    // Retire what this run did not produce, so a bundle whose pieces went out
    // of stock stops being offered. Same discipline as the affinity rebuild.
    if (built.length) {
      await this.prisma.bundle.updateMany({
        where: { id: { notIn: built }, status: BundleStatus.GENERATED },
        data: { status: BundleStatus.RETIRED },
      });
    }

    this.logger.log(`Bundles: ${built.length} assembled from ${anchors.length} anchors`);
    return { bundles: built.length };
  }

  /** Live, in-stock pieces that can anchor an outfit. */
  private async anchors(limit: number) {
    const products = await this.prisma.product.findMany({
      where: {
        status: ProductStatus.ACTIVE,
        offers: { some: { status: OfferStatus.ACTIVE, stock: { gt: 0 }, priceSyp: { not: null } } },
        // Only pieces with complements are worth starting from.
        affinitiesFrom: { some: { kind: AffinityKind.COMPLEMENT } },
      },
      select: { id: true, title: true, description: true, rating: true },
      orderBy: { rating: 'desc' },
      take: limit * 3,
    });

    return products
      .filter((product) => {
        const slots = detectSlots(`${product.title} ${product.description}`);
        return slots.some((slot) => slot === 'DRESS' || slot === 'ABAYA');
      })
      .slice(0, limit);
  }

  /**
   * Build one bundle outward from an anchor.
   *
   * One piece per slot, best complement first. Returns null rather than a
   * half-outfit when the graph cannot fill enough slots — an incomplete
   * bundle is worse than none, because it presents as a solution and is not.
   */
  async assemble(anchorId: string): Promise<string | null> {
    const anchor = await this.prisma.product.findUnique({
      where: { id: anchorId },
      select: {
        id: true,
        title: true,
        description: true,
        minPriceSyp: true,
        offers: {
          where: { status: OfferStatus.ACTIVE, stock: { gt: 0 }, priceSyp: { not: null } },
          orderBy: { priceSyp: 'asc' },
          take: 1,
          select: { id: true, sellerId: true, priceSyp: true },
        },
      },
    });
    if (!anchor || !anchor.offers.length) return null;

    const anchorText = `${anchor.title} ${anchor.description}`;
    const anchorSlots = detectSlots(anchorText);
    const occasion = detectOccasion(anchorText);

    const complements = await this.prisma.productAffinity.findMany({
      where: {
        productId: anchorId,
        kind: { in: [AffinityKind.COMPLEMENT, AffinityKind.BOUGHT_TOGETHER] },
        related: {
          status: ProductStatus.ACTIVE,
          offers: { some: { status: OfferStatus.ACTIVE, stock: { gt: 0 }, priceSyp: { not: null } } },
        },
      },
      orderBy: { score: 'desc' },
      take: 30,
      include: {
        related: {
          select: {
            id: true,
            title: true,
            description: true,
            offers: {
              where: { status: OfferStatus.ACTIVE, stock: { gt: 0 }, priceSyp: { not: null } },
              orderBy: { priceSyp: 'asc' },
              take: 1,
              select: { id: true, sellerId: true, priceSyp: true },
            },
          },
        },
      },
    });

    type Chosen = {
      productId: string;
      offerId: string;
      sellerId: string;
      priceSyp: number;
      slot: string | null;
      reason: string;
      score: number;
    };

    const items: Chosen[] = [
      {
        productId: anchor.id,
        offerId: anchor.offers[0].id,
        sellerId: anchor.offers[0].sellerId,
        priceSyp: Number(anchor.offers[0].priceSyp ?? 0),
        slot: anchorSlots[0] ?? null,
        reason: 'القطعة الأساسية بالإطلالة.',
        score: 100,
      },
    ];
    const filled = new Set(items.map((i) => i.slot).filter(Boolean) as string[]);

    for (const complement of complements) {
      if (items.length >= MAX_ITEMS) break;
      const offer = complement.related.offers[0];
      if (!offer) continue;

      const slots = detectSlots(
        `${complement.related.title} ${complement.related.description}`,
      );
      const slot = slots.find((s) => WEARABLE_SLOTS.includes(s)) ?? null;
      // One piece per slot: a bundle with two bags is a shopping list.
      if (!slot || filled.has(slot)) continue;

      // And it has to suit the same occasion. The same rule the product notes
      // apply, from the same function — a maternity bag does not complete a
      // wedding look, and finding that out twice would be finding it out in
      // two places that can drift apart.
      const complementOccasion = detectOccasion(
        `${complement.related.title} ${complement.related.description}`,
      );
      if (
        !occasionCompatible(occasion, complementOccasion ? [complementOccasion] : [])
      ) {
        continue;
      }

      const basis = (complement.basis ?? {}) as Record<string, unknown>;
      const observed =
        typeof basis['coOccurrences'] === 'number' && basis['coOccurrences'] > 0;

      items.push({
        productId: complement.relatedId,
        offerId: offer.id,
        sellerId: offer.sellerId,
        priceSyp: Number(offer.priceSyp ?? 0),
        slot,
        // The reason is the difference between a bundle and a gift basket.
        reason: observed
          ? `بنات كتير اشترتها مع «${anchor.title}».`
          : `بتكمّل «${anchor.title}» بنفس المناسبة.`,
        score: complement.score,
      });
      filled.add(slot);
    }

    if (items.length < MIN_ITEMS) return null;

    // How well it holds together: the mean of the complement scores, lifted a
    // little for covering more of an outfit.
    const meanScore =
      items.slice(1).reduce((t, i) => t + i.score, 0) / (items.length - 1);
    const coverage = filled.size / CORE_SLOTS.length;
    const score = Math.round(Math.min(100, meanScore * 0.8 + coverage * 40));
    if (score < MIN_SCORE) return null;

    const productIds = items.map((i) => i.productId).sort();
    const fingerprint = createHash('sha1')
      .update(productIds.join('|'))
      .digest('hex');

    const total = items.reduce((t, i) => t + i.priceSyp, 0);
    const sellerCount = new Set(items.map((i) => i.sellerId)).size;
    // Named after the piece it was built around, not just its occasion: three
    // evening looks all called «إطلالة سهرة كاملة» is a list she cannot read.
    const title = occasion
      ? `إطلالة ${occasionLabel(occasion) ?? occasion} حول «${anchor.title}»`
      : `إطلالة حول «${anchor.title}»`;

    const bundle = await this.prisma.bundle.upsert({
      where: { fingerprint },
      create: {
        fingerprint,
        title,
        occasion,
        status: BundleStatus.GENERATED,
        totalSyp: new Prisma.Decimal(total),
        sellerCount,
        score,
        slots: [...filled],
        basis: {
          anchorId: anchor.id,
          coverage: Math.round(coverage * 100),
          meanComplementScore: Math.round(meanScore),
        } as Prisma.InputJsonValue,
        items: {
          create: items.map((item, index) => ({
            productId: item.productId,
            offerId: item.offerId,
            slot: item.slot,
            position: index,
            reason: item.reason,
          })),
        },
      },
      update: {
        title,
        occasion,
        status: BundleStatus.GENERATED,
        totalSyp: new Prisma.Decimal(total),
        sellerCount,
        score,
        slots: [...filled],
        computedAt: new Date(),
      },
    });

    return bundle.id;
  }

  /** Bundles for a shopper to browse, best first. */
  async list(options: { occasion?: string; limit?: number } = {}) {
    return this.prisma.bundle.findMany({
      where: {
        status: { in: [BundleStatus.GENERATED, BundleStatus.CURATED] },
        ...(options.occasion ? { occasion: options.occasion } : {}),
      },
      orderBy: [{ score: 'desc' }, { sellerCount: 'desc' }],
      take: options.limit ?? 12,
      include: {
        items: {
          orderBy: { position: 'asc' },
          include: {
            product: {
              select: {
                id: true,
                title: true,
                media: { take: 1, orderBy: { sortOrder: 'asc' }, select: { url: true } },
              },
            },
            offer: {
              select: {
                id: true,
                priceSyp: true,
                // The shop's name, because "four shops, one look" is the whole
                // claim a bundle card makes and it cannot make it blank.
                seller: { select: { id: true, name: true } },
              },
            },
          },
        },
      },
    });
  }

  async detail(bundleId: string) {
    const bundle = await this.prisma.bundle.findUnique({
      where: { id: bundleId },
      include: {
        items: {
          orderBy: { position: 'asc' },
          include: {
            product: {
              select: {
                id: true,
                title: true,
                rating: true,
                media: { take: 1, orderBy: { sortOrder: 'asc' }, select: { url: true } },
              },
            },
            offer: {
              select: {
                id: true,
                priceSyp: true,
                stock: true,
                status: true,
                seller: { select: { id: true, name: true } },
              },
            },
          },
        },
      },
    });
    if (!bundle) throw new NotFoundException('Bundle not found');
    return bundle;
  }

  /**
   * Cheaper ways to fill the same slots.
   *
   * The comparison the brief asked for. Substitutes come from the graph, so
   * an alternative is one Reem already believes is genuinely equivalent — not
   * merely the cheapest thing in the category.
   */
  async alternativesFor(bundleId: string) {
    const bundle = await this.detail(bundleId);
    const out: Array<{
      slot: string | null;
      current: { productId: string; title: string; priceSyp: number };
      alternative: { productId: string; title: string; priceSyp: number };
      savingSyp: number;
    }> = [];

    for (const item of bundle.items) {
      if (!item.offer) continue;
      const substitute = await this.prisma.productAffinity.findFirst({
        where: {
          productId: item.productId,
          kind: AffinityKind.SUBSTITUTE,
          related: {
            status: ProductStatus.ACTIVE,
            offers: { some: { status: OfferStatus.ACTIVE, stock: { gt: 0 }, priceSyp: { not: null } } },
          },
        },
        orderBy: { score: 'desc' },
        include: {
          related: {
            select: {
              id: true,
              title: true,
              offers: {
                where: { status: OfferStatus.ACTIVE, stock: { gt: 0 }, priceSyp: { not: null } },
                orderBy: { priceSyp: 'asc' },
                take: 1,
                select: { priceSyp: true },
              },
            },
          },
        },
      });
      if (!substitute?.related.offers.length) continue;

      const current = Number(item.offer.priceSyp ?? 0);
      const cheaper = Number(substitute.related.offers[0].priceSyp ?? 0);
      if (cheaper <= 0 || cheaper >= current) continue;

      out.push({
        slot: item.slot,
        current: {
          productId: item.productId,
          title: item.product.title,
          priceSyp: current,
        },
        alternative: {
          productId: substitute.relatedId,
          title: substitute.related.title,
          priceSyp: cheaper,
        },
        savingSyp: Math.round(current - cheaper),
      });
    }

    return out;
  }

  /**
   * The lines a bundle would put through checkout.
   *
   * Handed to the same `checkoutLines` door a room's purchase plan uses, which
   * is the reason bundles can cross sellers at all — that path already knows
   * how to split an order between shops. Returned rather than checked out here
   * so the caller keeps the transaction.
   */
  async purchasableLines(bundleId: string) {
    const bundle = await this.detail(bundleId);
    const unavailable = bundle.items.filter(
      (item) =>
        !item.offer ||
        item.offer.status !== OfferStatus.ACTIVE ||
        item.offer.stock <= 0,
    );

    return {
      bundle,
      unavailable: unavailable.map((item) => item.productId),
      lines: bundle.items
        .filter(
          (item) =>
            item.offer &&
            item.offer.status === OfferStatus.ACTIVE &&
            item.offer.stock > 0,
        )
        .map((item) => ({
          offerId: item.offerId as string,
          offerVariantId: null,
          quantity: 1,
        })),
    };
  }
}
