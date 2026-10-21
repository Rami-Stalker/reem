import { Injectable } from '@nestjs/common';
import { Prisma, ValueBenefitKind } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ValueBenefitService } from './value-benefit.service';

/**
 * What her standing lets her see.
 *
 * Two of the benefits in the brief — Early Access and Exclusive Products — are
 * not perks bolted onto a product page, they are *visibility rules*, and the
 * only honest way to implement a visibility rule is in the query. A card that
 * renders and then says "you cannot have this" is an advertisement for a
 * feeling of exclusion; a catalogue that simply does not contain it yet is
 * early access.
 *
 * The service returns a `Prisma.ProductWhereInput` fragment rather than
 * filtering rows, so the exclusion happens in Postgres, pagination stays
 * correct, and a caller cannot accidentally leak a hidden product by forgetting
 * to filter after the fact.
 *
 * Deliberately **fail-open on error and fail-closed on doubt**: a woman with no
 * standing sees the ordinary catalogue (nothing is taken from her), and a
 * product inside an early-access window is hidden unless she demonstrably holds
 * the benefit.
 */
@Injectable()
export class ValueVisibilityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly benefits: ValueBenefitService,
  ) {}

  /**
   * The clause to AND into any customer-facing product query.
   *
   * Returns `{}` when there is nothing to hide, which is the common case and
   * costs one cached read.
   */
  async catalogFilter(viewerId?: string): Promise<Prisma.ProductWhereInput> {
    const [earlyAccess, exclusive] = await Promise.all([
      this.earlyAccessClause(viewerId),
      this.exclusiveClause(viewerId),
    ]);

    const clauses = [earlyAccess, exclusive].filter(
      (clause): clause is Prisma.ProductWhereInput => clause !== null,
    );
    if (!clauses.length) return {};
    return { AND: clauses };
  }

  /**
   * Which of these products she may see — for lists that are cached for
   * everyone, where the clause cannot go into the query.
   *
   * A list built once and served to every viewer has to drop what this viewer
   * cannot open after the fact; otherwise it shows a card whose page answers
   * «not found», which is worse than not showing it.
   */
  async visibleAmong(
    viewerId: string | undefined,
    productIds: readonly string[],
  ): Promise<Set<string>> {
    if (!productIds.length) return new Set();
    const filter = await this.catalogFilter(viewerId);
    if (!Object.keys(filter).length) return new Set(productIds);
    const rows = await this.prisma.product.findMany({
      where: { AND: [{ id: { in: [...productIds] } }, filter] },
      select: { id: true },
    });
    return new Set(rows.map((row) => row.id));
  }

  /**
   * New arrivals inside their embargo.
   *
   * A product is in early access for `config.hours` after it was created.
   * Nobody without the benefit sees it; everybody sees it afterwards. Keyed on
   * `createdAt` rather than a new column because an embargo that applies to
   * *everything new* needs no per-product decision, and a per-product one can be
   * layered on later as an exclusive.
   */
  private async earlyAccessClause(
    viewerId?: string,
  ): Promise<Prisma.ProductWhereInput | null> {
    const benefit = await this.prisma.valueBenefit.findFirst({
      where: { kind: ValueBenefitKind.EARLY_ACCESS, isActive: true },
      select: { key: true, config: true },
    });
    if (!benefit) return null;

    const hours = Number(
      (benefit.config as Record<string, unknown> | null)?.['hours'] ?? 0,
    );
    if (!hours) return null;

    if (viewerId && (await this.benefits.isUnlocked(viewerId, benefit.key))) {
      return null;
    }

    return { createdAt: { lt: new Date(Date.now() - hours * 3_600_000) } };
  }

  /** Pieces named on an exclusive benefit she does not hold. */
  private async exclusiveClause(
    viewerId?: string,
  ): Promise<Prisma.ProductWhereInput | null> {
    const benefits = await this.prisma.valueBenefit.findMany({
      where: { kind: ValueBenefitKind.EXCLUSIVE_PRODUCT, isActive: true },
      select: { key: true, config: true },
    });
    if (!benefits.length) return null;

    const hidden: string[] = [];
    for (const benefit of benefits) {
      const ids = (benefit.config as Record<string, unknown> | null)?.[
        'productIds'
      ];
      if (!Array.isArray(ids) || !ids.length) continue;
      if (viewerId && (await this.benefits.isUnlocked(viewerId, benefit.key))) {
        continue;
      }
      hidden.push(...ids.map(String));
    }

    if (!hidden.length) return null;
    return { id: { notIn: [...new Set(hidden)] } };
  }

  /**
   * Why a product she *can* see is special, for the badge on its card.
   *
   * The other half of the feature. Hiding what she cannot have is only worth
   * doing if what she can have is visibly hers — a piece nobody else can buy,
   * shown without a badge, is indistinguishable from an ordinary piece.
   */
  async badgesFor(
    viewerId: string,
    productIds: readonly string[],
  ): Promise<Map<string, 'EARLY_ACCESS' | 'EXCLUSIVE'>> {
    const badges = new Map<string, 'EARLY_ACCESS' | 'EXCLUSIVE'>();
    if (!productIds.length) return badges;

    const exclusives = await this.prisma.valueBenefit.findMany({
      where: { kind: ValueBenefitKind.EXCLUSIVE_PRODUCT, isActive: true },
      select: { key: true, config: true },
    });
    for (const benefit of exclusives) {
      const ids = (benefit.config as Record<string, unknown> | null)?.[
        'productIds'
      ];
      if (!Array.isArray(ids)) continue;
      if (!(await this.benefits.isUnlocked(viewerId, benefit.key))) continue;
      for (const id of ids.map(String)) {
        if (productIds.includes(id)) badges.set(id, 'EXCLUSIVE');
      }
    }

    const early = await this.prisma.valueBenefit.findFirst({
      where: { kind: ValueBenefitKind.EARLY_ACCESS, isActive: true },
      select: { key: true, config: true },
    });
    if (early && (await this.benefits.isUnlocked(viewerId, early.key))) {
      const hours = Number(
        (early.config as Record<string, unknown> | null)?.['hours'] ?? 0,
      );
      if (hours) {
        const embargoed = await this.prisma.product.findMany({
          where: {
            id: { in: [...productIds] },
            createdAt: { gte: new Date(Date.now() - hours * 3_600_000) },
          },
          select: { id: true },
        });
        for (const product of embargoed) {
          // Exclusive wins: it is the rarer statement about the piece.
          if (!badges.has(product.id)) badges.set(product.id, 'EARLY_ACCESS');
        }
      }
    }

    return badges;
  }
}
