import { Module } from '@nestjs/common';
import { ValueAdminController, ValueController } from './value.controller';
import { ValueAdminService } from './value.admin.service';
import { ValueBenefitService } from './value-benefit.service';
import { ValueCollectorService } from './value-collector.service';
import { ValuePolicyService } from './value-policy.service';
import { ValueScoringService } from './value-scoring.service';
import { ValueScheduler } from './value.scheduler';
import { ValueService } from './value.service';
import { ValueVisibilityService } from './value-visibility.service';

/**
 * Reem Value.
 *
 * Her standing on the platform, computed from the quality of her relationship
 * with it rather than from what she has spent, and the benefits that standing
 * opens.
 *
 * ── What it replaces, and what it deliberately does not ──────────────────
 *
 * It replaces the *status* half of the old loyalty programme: `MembershipTier`
 * keyed on `lifetime_points`, and `LoyaltyReward` bought by spending points.
 * Those made a ladder out of a wallet, which is precisely the thing the brief
 * asked not to build.
 *
 * It does **not** replace `PointsTransaction` or `LoyaltyService`. Those carry
 * Q43 — «كل 10 نقاط = 5,000 ل.س رصيد» — which the client specified verbatim and
 * which `LedgerService` posts as a real liability against `LOYALTY_LIABILITY`.
 * Deleting a ledger-backed monetary promise to make room for a status programme
 * would be unwinding a financial instrument to ship a feature. Points are now
 * plainly what they always were — cashback credit — and standing is a different
 * thing that is never spent.
 *
 * ── Why there is no earning endpoint ─────────────────────────────────────
 *
 * `ValueCollectorService` discovers contributions by querying for their
 * evidence. No module calls in to say something happened, and no client can ask
 * for standing. A status that can be requested is a status that can be
 * manufactured, and the absence of that route is the anti-manipulation design
 * at its simplest.
 *
 * ── Where the next features attach ───────────────────────────────────────
 *
 * All of them are new *rows*, not new tables:
 *
 *  - **A seventh pillar.** Add a `ValuePillar` value, a weight and a scale to
 *    the policy, and a source to the collector's `sources` list.
 *  - **A trend-aware DISCOVERY.** `ProductTrendScore` already knows what is
 *    climbing; confirming an early find against a trend score rather than a raw
 *    order count is a change to one query.
 *  - **Seller standing.** The tables are keyed on `userId`, not on a role. A
 *    seller ladder is a second set of `ValueTier` rows and a second policy.
 *  - **Benefits that cost money.** `unitCostSyp` and `totalBudget` exist and are
 *    reported; a payout rail would attach at `ValueBenefitService.grant`.
 */
@Module({
  controllers: [ValueController, ValueAdminController],
  providers: [
    ValuePolicyService,
    ValueScoringService,
    ValueCollectorService,
    ValueBenefitService,
    ValueService,
    ValueAdminService,
    ValueScheduler,
    ValueVisibilityService,
  ],
  // `ValueBenefitService` is exported for the surfaces that decorate themselves
  // with standing — checkout's enhanced returns, the catalog's early access,
  // support's queue order. They ask "is this open to her" and never learn what
  // a tier is.
  exports: [
    ValueService,
    ValueBenefitService,
    ValueScoringService,
    ValueVisibilityService,
  ],
})
export class ValueModule {}
