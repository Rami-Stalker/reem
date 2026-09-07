import { Injectable, Logger } from '@nestjs/common';
import {
  CommerceAttributionSource,
  CommerceAuthorKind,
  OfferStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';

/**
 * Which boutiques a piece of content earns credit for, and why.
 *
 * The single writer of `commerce_content_attributions`. That table is a
 * projection — every row is derivable from the content's author, its product
 * tags and its reshares — so nothing else may write it, and correctness is a
 * property of this class rather than of an index over three nullable columns.
 *
 * It exists because the derivation is a three-way join fanning out through
 * `seller_offers`, and the boutique dashboard asks on every load. Without it,
 * "which women are promoting my products" is the query that gets slower every
 * week the platform succeeds.
 */
@Injectable()
export class ContentAttributionService {
  private readonly logger = new Logger(ContentAttributionService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Recompute every attribution for one piece of content.
   *
   * Delete-then-insert rather than a diff: the row count is small (one per
   * seller per tagged product), the inputs change together, and a diff would
   * be three times the code to reach the same state with more ways to be
   * subtly wrong.
   */
  async rebuild(contentId: string, tx?: Prisma.TransactionClient) {
    const db = tx ?? this.prisma;

    const content = await db.commerceContent.findUnique({
      where: { id: contentId },
      select: {
        id: true,
        authorId: true,
        authorKind: true,
        createdAt: true,
        productTags: { select: { productId: true } },
      },
    });
    if (!content) return 0;

    const rows: Prisma.CommerceContentAttributionCreateManyInput[] = [];

    // The boutique wrote it herself.
    if (content.authorKind === CommerceAuthorKind.SELLER) {
      rows.push({
        contentId: content.id,
        sellerId: content.authorId,
        source: CommerceAttributionSource.AUTHOR,
        actorId: content.authorId,
        createdAt: content.createdAt,
      });
    }

    // Somebody tagged a product a boutique sells. Live offers only — an
    // archived listing is not something anybody is promoting.
    const productIds = [
      ...new Set(content.productTags.map((tag) => tag.productId)),
    ];
    if (productIds.length > 0) {
      const offers = await db.sellerOffer.findMany({
        where: {
          productId: { in: productIds },
          status: OfferStatus.ACTIVE,
          isActive: true,
        },
        select: { sellerId: true, productId: true },
      });
      for (const offer of offers) {
        // A boutique tagging her own product in her own post is already
        // credited as AUTHOR; a second row would double every count.
        if (offer.sellerId === content.authorId) continue;
        rows.push({
          contentId: content.id,
          sellerId: offer.sellerId,
          source: CommerceAttributionSource.PRODUCT_TAG,
          productId: offer.productId,
          actorId: content.authorId,
          createdAt: content.createdAt,
        });
      }
    }

    // And every page it has been added to.
    const reshares = await db.commerceContentReshare.findMany({
      where: { sourceContentId: content.id },
      select: { id: true, resharerId: true, createdAt: true },
    });
    if (reshares.length > 0) {
      const credited = rows
        .filter((row) => row.source !== CommerceAttributionSource.RESHARE)
        .map((row) => ({ sellerId: row.sellerId, productId: row.productId }));
      for (const reshare of reshares) {
        for (const credit of credited) {
          rows.push({
            contentId: content.id,
            sellerId: credit.sellerId,
            source: CommerceAttributionSource.RESHARE,
            productId: credit.productId ?? null,
            reshareId: reshare.id,
            actorId: reshare.resharerId,
            createdAt: reshare.createdAt,
          });
        }
      }
    }

    await db.commerceContentAttribution.deleteMany({ where: { contentId } });
    if (rows.length === 0) return 0;
    await db.commerceContentAttribution.createMany({ data: rows });
    return rows.length;
  }

  /**
   * Nightly catch-up.
   *
   * Attribution is deliberately **not** rewritten when a seller starts or stops
   * offering a product: a boutique adding a listing that is already tagged in
   * four hundred posts would trigger a four-hundred-row fan-out on a write path
   * that has nothing to do with content. The lag is the trade, and this closes
   * it — which is the whole reason the table is framed as a rebuildable
   * projection rather than a fact.
   */
  async rebuildStale(sinceDays = 30, limit = 2_000) {
    const since = new Date(Date.now() - sinceDays * 86_400_000);
    const contents = await this.prisma.commerceContent.findMany({
      where: { updatedAt: { gte: since } },
      select: { id: true },
      orderBy: { updatedAt: 'desc' },
      take: limit,
    });

    let written = 0;
    for (const content of contents) {
      written += await this.rebuild(content.id);
    }
    this.logger.log(
      `attribution rebuild: ${contents.length} contents, ${written} rows`,
    );
    return { contents: contents.length, rows: written };
  }
}
