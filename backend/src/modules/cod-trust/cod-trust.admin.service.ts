import { Injectable } from '@nestjs/common';
import { CodAssurance, CodAssuranceState, CodRiskTier } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { sellerLabelFor } from './cod-trust.service';

const TIERS: CodRiskTier[] = [
  CodRiskTier.TRUSTED,
  CodRiskTier.LOW,
  CodRiskTier.MEDIUM,
  CodRiskTier.HIGH,
];

/**
 * The console the engine is judged from.
 *
 * The important number here is not how much friction the platform added — it
 * is the **calibration table**: for each tier, how many of those parcels
 * actually came back. An engine whose `HIGH` bucket refuses at the same rate
 * as its `LOW` bucket is sorting customers at random and adding friction for
 * nothing, and this report is the only place that becomes visible.
 *
 * It is deliberately a report and not a dashboard tile. Nobody should be
 * nudging weights on a Tuesday because one number moved; the shape of the
 * table over a month is the thing to read.
 */
@Injectable()
export class CodTrustAdminService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(days = 30) {
    const since = new Date(Date.now() - days * 86_400_000);

    const [byTier, byAssurance, exposure, pending, blocked] = await Promise.all([
      this.prisma.codRiskAssessment.groupBy({
        by: ['tier', 'observedOutcome'],
        where: { createdAt: { gte: since } },
        _count: { _all: true },
      }),
      this.prisma.codRiskAssessment.groupBy({
        by: ['assurance'],
        where: { createdAt: { gte: since } },
        _count: { _all: true },
        _sum: { exposureUsd: true },
      }),
      this.prisma.codRiskAssessment.aggregate({
        where: { createdAt: { gte: since } },
        _sum: { exposureUsd: true },
      }),
      this.prisma.codRiskAssessment.count({
        where: { state: CodAssuranceState.PENDING },
      }),
      // Baskets that never became cash orders leave no assessment row — only
      // an audit entry. Counting them here is what keeps "how often did we
      // refuse the cash rail" answerable at all.
      this.prisma.auditLog.count({
        where: {
          category: 'commerce.cod_trust',
          action: 'cod_assurance_required',
          outcome: CodAssurance.PREPAYMENT.toLowerCase(),
          createdAt: { gte: since },
        },
      }),
    ]);

    return {
      window_days: days,
      calibration: TIERS.map((tier) => {
        const rows = byTier.filter((row) => row.tier === tier);
        const count = (outcome: string | null) =>
          rows
            .filter((row) => row.observedOutcome === outcome)
            .reduce((total, row) => total + row._count._all, 0);

        const refused = count('refused');
        const delivered = count('delivered');
        const failed = count('failed');
        const settled = refused + delivered + failed;

        return {
          tier: tier.toLowerCase(),
          label: sellerLabelFor(tier),
          assessed: rows.reduce((total, row) => total + row._count._all, 0),
          // Only parcels that reached a door. An order still in transit says
          // nothing about whether the score was right, and averaging it in as
          // a success is how a model convinces itself it is working.
          settled,
          delivered,
          refused,
          failed,
          refusal_rate: settled > 0 ? round(refused / settled) : null,
        };
      }),
      friction: byAssurance.map((row) => ({
        assurance: row.assurance.toLowerCase(),
        orders: row._count._all,
        exposure_usd: row._sum.exposureUsd?.toString() ?? '0',
      })),
      /** Cash the platform put on the road in the window, USD. */
      total_exposure_usd: exposure._sum.exposureUsd?.toString() ?? '0',
      awaiting_confirmation: pending,
      /** Baskets asked to prepay rather than pay a courier. */
      cash_declined: blocked,
    };
  }
}

const round = (value: number): number => Math.round(value * 1000) / 1000;
