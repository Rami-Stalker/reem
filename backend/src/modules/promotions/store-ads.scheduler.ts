import { Injectable, Logger } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PromotionStatus } from '@prisma/client';
import {
  AdCampaignEndedPayload,
  AdPlanEndingPayload,
  AppEvent,
} from '../../common/events/app-events';
import { ScheduledJob } from '../../common/scheduling/scheduled-job.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { PromotionsService } from './promotions.service';

/** A plan's reminder goes out this many days before it ends. */
const REMIND_DAYS = 3;

/** Notices older than this are not sent late: they would only confuse her. */
const STALE_DAYS = 7;

/**
 * The two things a boutique must hear without opening the app.
 *
 * - **Her plan is ending.** Plans never renew by themselves, which is right —
 *   and it means that without a word from us her adverts would simply stop
 *   leading one morning. Three days before, and once it has ended, unless she
 *   has already renewed.
 * - **A campaign finished.** What it reached and what it sold, and the
 *   campaign is marked ended.
 *
 * Each notice is sent once: the row is stamped in the same update that claims
 * it, so two instances running the job cannot both send it.
 */
@Injectable()
export class StoreAdsScheduler {
  private readonly logger = new Logger(StoreAdsScheduler.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly promotions: PromotionsService,
    private readonly events: EventEmitter2,
  ) {}

  @ScheduledJob({ cron: '0 20 * * * *', staleAfterMinutes: 180 })
  async run(): Promise<void> {
    await this.remindEndingPlans();
    await this.closeEndedCampaigns();
  }

  async remindEndingPlans(now = new Date()): Promise<void> {
    const soon = new Date(now.getTime() + REMIND_DAYS * 86_400_000);
    const stale = new Date(now.getTime() - STALE_DAYS * 86_400_000);

    const ending = await this.prisma.storeAdSubscription.findMany({
      where: { reminderSentAt: null, endsAt: { gt: now, lte: soon }, startsAt: { lte: now } },
      take: 200,
    });
    for (const sub of ending) {
      if (await this.hasNext(sub.sellerId, sub.endsAt)) continue;
      if (!(await this.claim(sub.id, 'reminderSentAt', now))) continue;
      const payload: AdPlanEndingPayload = {
        sellerId: sub.sellerId,
        subscriptionId: sub.id,
        tier: sub.tier,
        daysLeft: Math.max(1, Math.ceil((sub.endsAt.getTime() - now.getTime()) / 86_400_000)),
      };
      this.events.emit(AppEvent.AdPlanEnding, payload);
    }

    const ended = await this.prisma.storeAdSubscription.findMany({
      where: { endedNoticeSentAt: null, endsAt: { lte: now, gt: stale } },
      take: 200,
    });
    for (const sub of ended) {
      if (await this.hasNext(sub.sellerId, sub.endsAt)) continue;
      if (!(await this.claim(sub.id, 'endedNoticeSentAt', now))) continue;
      const payload: AdPlanEndingPayload = {
        sellerId: sub.sellerId,
        subscriptionId: sub.id,
        tier: sub.tier,
        daysLeft: 0,
      };
      this.events.emit(AppEvent.AdPlanEnding, payload);
    }
  }

  async closeEndedCampaigns(now = new Date()): Promise<void> {
    const stale = new Date(now.getTime() - STALE_DAYS * 86_400_000);
    const finished = await this.prisma.productPromotion.findMany({
      where: {
        endedNoticeSentAt: null,
        chargedAt: { not: null },
        endsAt: { lte: now, gt: stale },
        status: { in: [PromotionStatus.ACTIVE, PromotionStatus.PAUSED] },
      },
      include: { offer: { select: { product: { select: { title: true } } } } },
      take: 200,
    });
    if (finished.length === 0) return;
    const stats = await this.promotions.performance(finished.map((p) => p.id));

    for (const promotion of finished) {
      const claimed = await this.prisma.productPromotion.updateMany({
        where: { id: promotion.id, endedNoticeSentAt: null },
        data: { endedNoticeSentAt: now, status: PromotionStatus.ENDED },
      });
      if (claimed.count === 0) continue;
      const s = stats.get(promotion.id);
      const payload: AdCampaignEndedPayload = {
        sellerId: promotion.sellerId,
        promotionId: promotion.id,
        productTitle: promotion.offer.product.title,
        reach: s?.reach ?? 0,
        clicks: promotion.clicks,
        orders: s?.attributed_orders ?? 0,
      };
      this.events.emit(AppEvent.AdCampaignEnded, payload);
    }
    this.logger.log(`Closed ${finished.length} finished campaign(s)`);
  }

  /** She already has a plan that starts when this one ends — she renewed. */
  private async hasNext(sellerId: string, endsAt: Date): Promise<boolean> {
    const next = await this.prisma.storeAdSubscription.findFirst({
      where: { sellerId, startsAt: { gte: new Date(endsAt.getTime() - 60_000) }, endsAt: { gt: endsAt } },
      select: { id: true },
    });
    return next !== null;
  }

  private async claim(
    id: string,
    field: 'reminderSentAt' | 'endedNoticeSentAt',
    now: Date,
  ): Promise<boolean> {
    const claimed = await this.prisma.storeAdSubscription.updateMany({
      where: { id, [field]: null },
      data: { [field]: now },
    });
    return claimed.count === 1;
  }
}
