import { Injectable, NotFoundException } from '@nestjs/common';
import { Currency, Prisma, RoomCandidateStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';
import { ExchangeRateService } from '../pricing/exchange-rate.service';
import { RoomAccessService } from './room-access.service';
import {
  CompareInput,
  CompareRow,
  CompareVerdict,
  buildComparison,
  orderComparison,
  verdictFor,
} from './kernel/candidate-comparison';
import { consensusFor, Consensus } from './kernel/room-readiness';

const COMPARE_INCLUDE = {
  offer: {
    include: {
      seller: {
        select: {
          id: true,
          name: true,
          sellerLevel: true,
          sellerReputation: { select: { averageRating: true } },
        },
      },
      product: {
        include: {
          brand: true,
          category: true,
          media: { orderBy: { sortOrder: 'asc' as const }, take: 1 },
        },
      },
    },
  },
  offerVariant: { include: { variant: true } },
} satisfies Prisma.RoomCandidateInclude;

export interface Comparison {
  decisionId: string;
  decisionTitle: string;
  candidateIds: string[];
  rows: CompareRow[];
  consensus: Consensus;
  verdict: { code: CompareVerdict; candidateId: string | null };
  /** How many comments each candidate has drawn — the argument's own weight. */
  commentCounts: Record<string, number>;
}

/**
 * Putting the options side by side.
 *
 * The room's compare view. What makes it worth having over the horizontal rail
 * is that it does the reading for her: every attribute is gathered, the ones
 * where the candidates agree are marked and collapsed, and what is left is the
 * ground the decision actually turns on.
 *
 * Prices are normalised to SYP before comparison and *displayed* in the
 * seller's own currency — otherwise "cheapest" would be a comparison of
 * numerals rather than of money, which is the bug the catalogue's `priceSyp`
 * column exists to prevent.
 *
 * Nothing here recommends. `verdictFor` names a candidate only when one wins
 * every measurable row, which is a fact about the options rather than an
 * opinion about her taste.
 */
@Injectable()
export class RoomCompareService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: RoomAccessService,
    private readonly rates: ExchangeRateService,
  ) {}

  async compare(
    roomId: string,
    userId: string,
    decisionId: string,
    only?: string[],
  ): Promise<Comparison> {
    await this.access.require(roomId, userId);

    const decision = await this.prisma.roomDecision.findFirst({
      where: { id: decisionId, roomId },
      select: { id: true, title: true },
    });
    if (!decision) throw new NotFoundException('Decision not found');

    const candidates = await this.prisma.roomCandidate.findMany({
      where: {
        decisionId,
        // Rejected options are out of the comparison: she has already ruled
        // them out, and re-presenting them is re-arguing a settled point.
        status: { not: RoomCandidateStatus.REJECTED },
        ...(only?.length ? { id: { in: only } } : {}),
      },
      include: COMPARE_INCLUDE,
      orderBy: { position: 'asc' },
    });

    if (candidates.length < 2) {
      return {
        decisionId: decision.id,
        decisionTitle: decision.title,
        candidateIds: candidates.map((candidate) => candidate.id),
        rows: [],
        consensus: consensusFor([]),
        verdict: { code: 'IDENTICAL', candidateId: null },
        commentCounts: {},
      };
    }

    const ids = candidates.map((candidate) => candidate.id);
    const priced = await Promise.all(
      candidates.map(async (candidate) => ({
        candidate,
        syp: await this.priceSyp(candidate),
      })),
    );

    const comments = await this.prisma.roomComment.groupBy({
      by: ['candidateId'],
      where: { candidateId: { in: ids } },
      _count: { _all: true },
    });
    const commentCounts = Object.fromEntries(
      comments
        .filter((row) => row.candidateId)
        .map((row) => [row.candidateId!, row._count._all]),
    );

    const inputs: CompareInput[] = [
      {
        key: 'price',
        label: 'السعر',
        direction: 'lower',
        values: Object.fromEntries(
          priced.map(({ candidate, syp }) => [
            candidate.id,
            {
              // Compared in SYP, shown in the seller's own currency — the
              // comparison must not become a comparison of numerals.
              raw: syp,
              // The seller's own currency on screen, SYP in `raw` above: the
              // comparison must compare money, not numerals.
              display: displayPrice(
                Money.of(
                  candidate.offerVariant?.price ?? candidate.offer.price,
                  candidate.offer.currency,
                ),
              ),
            },
          ]),
        ),
      },
      {
        key: 'seller',
        label: 'المتجر',
        values: this.stringRow(candidates, (c) => c.offer.seller.name),
      },
      {
        key: 'rating',
        label: 'تقييم المتجر',
        direction: 'higher',
        values: Object.fromEntries(
          candidates.map((candidate) => {
            const rating = candidate.offer.seller.sellerReputation?.averageRating ?? null;
            return [
              candidate.id,
              {
                raw: rating === null ? null : Number(rating),
                display: rating === null ? '—' : Number(rating).toFixed(1),
              },
            ];
          }),
        ),
      },
      {
        key: 'delivery',
        label: 'مدة التجهيز',
        direction: 'lower',
        values: Object.fromEntries(
          candidates.map((candidate) => [
            candidate.id,
            {
              raw: candidate.offer.handlingDays,
              display: `${candidate.offer.handlingDays} يوم`,
            },
          ]),
        ),
      },
      {
        key: 'stock',
        label: 'المتوفر',
        direction: 'higher',
        values: Object.fromEntries(
          candidates.map((candidate) => {
            const stock = candidate.offerVariant?.stock ?? candidate.offer.stock;
            return [
              candidate.id,
              { raw: stock, display: stock > 0 ? `${stock}` : 'نفد' },
            ];
          }),
        ),
      },
      {
        key: 'variant',
        label: 'الخيار',
        values: this.stringRow(
          candidates,
          (c) => c.offerVariant?.variant.name ?? null,
        ),
      },
      {
        key: 'brand',
        label: 'الماركة',
        values: this.stringRow(candidates, (c) => c.offer.product.brand?.nameAr ?? null),
      },
      {
        key: 'returns',
        label: 'الإرجاع',
        values: Object.fromEntries(
          candidates.map((candidate) => [
            candidate.id,
            {
              raw: candidate.offer.acceptsReturns ? 'yes' : 'no',
              display: candidate.offer.acceptsReturns ? 'قابلة للإرجاع' : 'غير قابلة للإرجاع',
            },
          ]),
        ),
      },
      {
        key: 'votes',
        label: 'رأي الغرفة',
        direction: 'higher',
        values: Object.fromEntries(
          candidates.map((candidate) => [
            candidate.id,
            {
              raw: candidate.voteScore,
              display: candidate.votesUp + candidate.votesDown === 0
                ? 'لا أصوات بعد'
                : `${candidate.votesUp}↑ ${candidate.votesDown}↓`,
            },
          ]),
        ),
      },
    ];

    const rows = orderComparison(buildComparison(inputs));

    return {
      decisionId: decision.id,
      decisionTitle: decision.title,
      candidateIds: ids,
      rows,
      consensus: consensusFor(
        candidates.map((candidate) => ({
          id: candidate.id,
          status: candidate.status,
          quantity: candidate.quantity,
          votesUp: candidate.votesUp,
          votesDown: candidate.votesDown,
          voteScore: candidate.voteScore,
          unitPriceSyp: null,
          purchasable: true,
        })),
      ),
      verdict: verdictFor(rows, ids),
      commentCounts,
    };
  }

  /** A row of plain strings, where "not set" is itself a value worth showing. */
  private stringRow(
    candidates: Prisma.RoomCandidateGetPayload<{ include: typeof COMPARE_INCLUDE }>[],
    read: (
      candidate: Prisma.RoomCandidateGetPayload<{ include: typeof COMPARE_INCLUDE }>,
    ) => string | null,
  ): Record<string, { raw: string | null; display: string }> {
    return Object.fromEntries(
      candidates.map((candidate) => {
        const value = read(candidate);
        return [candidate.id, { raw: value, display: value ?? '—' }];
      }),
    );
  }

  private async priceSyp(candidate: {
    offer: {
      price: Prisma.Decimal;
      currency: Currency;
      priceSyp: Prisma.Decimal | null;
    };
    offerVariant: { price: Prisma.Decimal | null } | null;
  }): Promise<number | null> {
    const variantPrice = candidate.offerVariant?.price;
    if (!variantPrice && candidate.offer.priceSyp) {
      return Number(candidate.offer.priceSyp);
    }
    try {
      const syp = await this.rates.toSyp(
        Money.of(variantPrice ?? candidate.offer.price, candidate.offer.currency),
      );
      return Number(syp.toJSON().amount);
    } catch {
      return null;
    }
  }
}

/**
 * A price as a person reads it.
 *
 * The backend `Money` deliberately has no formatter — display is the client's
 * job everywhere else in this codebase, and money crosses the wire as
 * `{amount, currency}`. A comparison cell is the exception: its whole payload is
 * a string to be shown beside other strings, so the row would be meaningless
 * split into a structured amount per cell.
 */
function displayPrice(money: Money): string {
  const { amount, currency } = money.toJSON();
  const whole = Number(amount).toLocaleString('en-US', {
    maximumFractionDigits: 0,
  });
  return currency === Currency.SYP ? `${whole} ل.س` : `${whole} $`;
}
