import { ForbiddenException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  ContentTagBasis,
  OfferStatus,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuthUser } from '../../../common/decorators/current-user.decorator';
import { buildMeta, PaginationDto } from '../../../common/dto/pagination.dto';

/**
 * Who may tag which product in a piece of content.
 *
 * This is the rule that stops the feature being an open door. A shoppable tag
 * is a claim — "this is the dress, and it is from that boutique" — and an
 * unchecked one lets anybody attach any shop's product to any photograph, or
 * attach a competitor's listing to something unflattering.
 *
 * Two things make it a service rather than a pure function beside
 * `common/authz.ts`: it needs the database, and the picker endpoint that shows
 * her what she *may* tag has to answer with the same rule the write path
 * enforces. One source, two callers.
 */

const MANAGER_ROLES: UserRole[] = [
  UserRole.SUPER_ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.CONTENT_MODERATOR,
  UserRole.ADMIN,
];

export interface TagVerdict {
  productId: string;
  /** `null` means refused. */
  basis: ContentTagBasis | null;

  /**
   * The delivered line that proves a `PURCHASE`. Recorded on the tag so an
   * audit a year from now can answer "why was she allowed to tag this", and so
   * a returns-driven cleanup has something to find.
   */
  sourceOrderItemId?: string;

  /** Machine-readable refusal, for a client that wants to explain itself. */
  refusal?: 'PRODUCT_NOT_PURCHASED' | 'PRODUCT_NOT_SOLD_BY_YOU';
}

@Injectable()
export class ProductTagPolicyService {
  private readonly logger = new Logger(ProductTagPolicyService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  /**
   * Whether the policy refuses, or merely reports what it would have refused.
   *
   * The rule below is genuinely stricter than what shipped: `productsForTags`
   * selected a product's offers with **no status filter**, so a boutique with
   * a draft, paused or archived listing can tag it today. Turning that off in
   * one release would start refusing sellers who have done nothing wrong and
   * have no way to find out why — so it runs in log-only mode first, the log
   * is read, and then it enforces.
   */
  private get enforcing(): boolean {
    return this.config.get<boolean>('content.enforceTagPolicy') ?? false;
  }

  /**
   * Verdicts for a set of products, keyed by product id.
   *
   * The bases are evaluated **in parallel and OR'd, never switched on role**.
   * A boutique owner who bought a dress from another boutique may post about
   * it like anybody else, and a `switch (user.role)` would refuse her forever
   * — a refusal that would read as a bug and never be traced back to a policy
   * decision nobody wrote down.
   */
  async verdicts(
    actor: AuthUser,
    productIds: readonly string[],
  ): Promise<Map<string, TagVerdict>> {
    const unique = [...new Set(productIds)];
    const verdicts = new Map<string, TagVerdict>();
    if (unique.length === 0) return verdicts;

    if (MANAGER_ROLES.includes(actor.role)) {
      for (const productId of unique) {
        verdicts.set(productId, { productId, basis: ContentTagBasis.ADMIN });
      }
      return verdicts;
    }

    const [offered, purchased] = await Promise.all([
      this.prisma.sellerOffer.findMany({
        where: {
          sellerId: actor.id,
          productId: { in: unique },
          // The tightening. An archived listing is not something she sells.
          status: OfferStatus.ACTIVE,
          isActive: true,
        },
        select: { productId: true },
        distinct: ['productId'],
      }),
      // The canonical purchase proof, lifted from
      // `reputation.service.ts:701-716` and inverted: no single-order scope,
      // and DELIVERED is read off the SELLER order because a basket from two
      // boutiques is fulfilled — and delivered — per boutique.
      this.prisma.orderItem.findMany({
        where: {
          productId: { in: unique },
          sellerOrder: {
            status: SellerOrderStatus.DELIVERED,
            order: { userId: actor.id },
          },
        },
        select: { id: true, productId: true },
        orderBy: { sellerOrder: { createdAt: 'desc' } },
      }),
    ]);

    const offeredIds = new Set(offered.map((offer) => offer.productId));
    const purchasedBy = new Map<string, string>();
    for (const item of purchased) {
      if (item.productId && !purchasedBy.has(item.productId)) {
        purchasedBy.set(item.productId, item.id);
      }
    }

    for (const productId of unique) {
      const orderItemId = purchasedBy.get(productId);
      if (orderItemId) {
        verdicts.set(productId, {
          productId,
          basis: ContentTagBasis.PURCHASE,
          sourceOrderItemId: orderItemId,
        });
        continue;
      }
      if (offeredIds.has(productId)) {
        verdicts.set(productId, {
          productId,
          basis: ContentTagBasis.SELLER_OFFER,
        });
        continue;
      }
      verdicts.set(productId, {
        productId,
        basis: null,
        refusal:
          actor.role === UserRole.SELLER
            ? 'PRODUCT_NOT_SOLD_BY_YOU'
            : 'PRODUCT_NOT_PURCHASED',
      });
    }

    return verdicts;
  }

  /**
   * The same question, as a gate. Throws on the first refusal.
   *
   * While the policy is not yet enforcing, a refusal is logged with enough to
   * act on — who, what, and which rule — and then allowed through as
   * `SELLER_OFFER`, which is what the old code would have recorded.
   */
  async assert(
    actor: AuthUser,
    productIds: readonly string[],
  ): Promise<Map<string, TagVerdict>> {
    const verdicts = await this.verdicts(actor, productIds);
    const refused = [...verdicts.values()].filter((v) => v.basis === null);
    if (refused.length === 0) return verdicts;

    if (!this.enforcing) {
      for (const verdict of refused) {
        this.logger.warn(
          `tag-policy would refuse: actor=${actor.id} role=${actor.role} ` +
            `product=${verdict.productId} rule=${verdict.refusal}`,
        );
        verdicts.set(verdict.productId, {
          ...verdict,
          basis: ContentTagBasis.SELLER_OFFER,
          refusal: undefined,
        });
      }
      return verdicts;
    }

    throw new ForbiddenException({
      message: 'You cannot tag one of these products',
      code: refused[0].refusal,
      product_ids: refused.map((verdict) => verdict.productId),
    });
  }

  /**
   * What she may tag, for the composer's picker.
   *
   * Her closet is the list a woman recognises — it is her own wardrobe, with
   * her own photographs — so it is what the picker shows. It is emphatically
   * **not** the authority, and the write path re-derives from orders
   * regardless, for three reasons that all live in the code:
   *
   *   1. `closet-intake.service.ts:66` returns early when `autoAddPurchases`
   *      is off. A woman who turned intake off owns garments her closet has
   *      never heard of, and would be told she cannot tag her own dress.
   *   2. A `PERSONAL` closet item was never bought here and carries a free
   *      nullable `productId`. Anyone could point one at any catalogue product
   *      — that is the whole exploit, and it would look like a feature.
   *   3. Items get archived and released, while `orderItem` is `SetNull`.
   *
   * So the ineligible are returned too, marked, rather than silently missing:
   * a picker that hides a dress she is holding is a bug report, and one that
   * greys it out with a reason is an explanation.
   */
  async listTaggable(actor: AuthUser, page: PaginationDto) {
    const isSeller = actor.role === UserRole.SELLER;

    if (isSeller) {
      const [offers, total] = await Promise.all([
        this.prisma.sellerOffer.findMany({
          where: {
            sellerId: actor.id,
            status: OfferStatus.ACTIVE,
            isActive: true,
          },
          select: {
            product: {
              select: {
                id: true,
                title: true,
                media: { orderBy: { sortOrder: 'asc' }, take: 1 },
              },
            },
          },
          orderBy: { updatedAt: 'desc' },
          skip: page.skip,
          take: page.limit,
        }),
        this.prisma.sellerOffer.count({
          where: {
            sellerId: actor.id,
            status: OfferStatus.ACTIVE,
            isActive: true,
          },
        }),
      ]);

      return {
        data: offers.map((offer) => ({
          product_id: offer.product.id,
          title: offer.product.title,
          image_url: offer.product.media[0]?.url ?? null,
          basis: ContentTagBasis.SELLER_OFFER,
          eligible: true,
          reason: null as string | null,
        })),
        pagination: buildMeta(page.page, page.limit, total, offers.length),
      };
    }

    // Everything she was actually handed, newest first. Driven off the order
    // side rather than the closet so a woman with intake switched off still
    // sees her purchases.
    const [lines, total] = await Promise.all([
      this.prisma.orderItem.findMany({
        where: {
          productId: { not: null },
          sellerOrder: {
            status: SellerOrderStatus.DELIVERED,
            order: { userId: actor.id },
          },
        },
        select: {
          id: true,
          productId: true,
          titleSnapshot: true,
          imageSnapshot: true,
          sellerOrder: { select: { createdAt: true } },
        },
        orderBy: { sellerOrder: { createdAt: 'desc' } },
        skip: page.skip,
        take: page.limit,
      }),
      this.prisma.orderItem.count({
        where: {
          productId: { not: null },
          sellerOrder: {
            status: SellerOrderStatus.DELIVERED,
            order: { userId: actor.id },
          },
        },
      }),
    ]);

    const seen = new Set<string>();
    const items = [];
    for (const line of lines) {
      if (!line.productId || seen.has(line.productId)) continue;
      seen.add(line.productId);
      items.push({
        product_id: line.productId,
        // The snapshot, not the live title: it is what her receipt says, and
        // it survives the boutique renaming or delisting the listing.
        title: line.titleSnapshot,
        image_url: line.imageSnapshot,
        basis: ContentTagBasis.PURCHASE,
        eligible: true,
        reason: null as string | null,
        source_order_item_id: line.id,
      });
    }

    return {
      data: items,
      pagination: buildMeta(page.page, page.limit, total, items.length),
    };
  }
}
