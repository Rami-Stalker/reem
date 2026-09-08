import { Injectable, Logger } from '@nestjs/common';
import {
  NotificationCategory,
  NotificationChannel,
  NotificationType,
  ReengagementKind,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CustomerSegmentsService } from './customer-segments.service';
import { LifecycleStage } from './customer-segments';

/**
 * How many people one run may reach.
 *
 * Low on purpose. A re-engagement job that can message the entire customer
 * base in one pass is one bad deploy away from doing exactly that, and there
 * is no way to un-send a push notification.
 */
const DEFAULT_BATCH = 200;

export interface Sent {
  reached: number;
  skipped: number;
}

/**
 * Reminders, and the discipline around them.
 *
 * Two campaigns the audit found missing, both of which are easy to build
 * badly. What separates a reminder from a nuisance is not the copy — it is
 * whether the platform remembers having sent one. Every send here goes through
 * `touch`, which writes a row under a unique key before the message goes out;
 * a second run finds the row and skips.
 *
 * Nothing here discounts anything. An abandoned-basket nudge that carries a
 * coupon teaches customers to abandon baskets, which is a lesson a marketplace
 * only has to learn once. Win-back is where an offer belongs, and even there
 * this service sends the message and leaves the offer to a campaign somebody
 * approved.
 */
@Injectable()
export class ReengagementService {
  private readonly logger = new Logger(ReengagementService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly segments: CustomerSegmentsService,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * Reminds women who left something in a basket.
   *
   * One message per basket, ever. The fingerprint changes when she edits it,
   * so a genuinely new basket earns a genuinely new reminder — and the same
   * four dresses she has been ignoring for a week earn silence.
   */
  async nudgeAbandonedBaskets(limit = DEFAULT_BATCH): Promise<Sent> {
    const baskets = await this.segments.abandonedBaskets(limit);
    let reached = 0;
    let skipped = 0;

    for (const basket of baskets) {
      const claimed = await this.touch(
        basket.userId,
        ReengagementKind.ABANDONED_CART,
        basket.fingerprint,
        'abandoned_cart',
      );
      if (!claimed) {
        skipped += 1;
        continue;
      }

      const body = basket.leadTitle
        ? `«${basket.leadTitle}»${basket.items > 1 ? ` و${basket.items - 1} قطعة أخرى` : ''} ما زالت في سلّتك.`
        : `لديك ${basket.items} قطعة في سلّتك.`;

      try {
        await this.notifications.dispatch('system', {
          user_ids: [basket.userId],
          channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH],
          type: NotificationType.system,
          title: 'سلّتك بانتظارك',
          body,
          payload: { deep_link: '/cart', kind: 'abandoned_cart' },
          // Explicit rather than relying on the default: this is the platform
          // wanting something, so it queues behind her frequency cap and her
          // quiet hours like every other promotion.
          category: NotificationCategory.MARKETING,
        });
        reached += 1;
      } catch (error) {
        // The touch row stays. Retrying a failed send on the next run would
        // need the row removed, and the cost of a missed reminder is far
        // below the cost of a loop that re-sends on every error.
        this.logger.warn(
          `Basket reminder not sent to ${basket.userId}: ${String(error)}`,
        );
      }
    }

    return { reached, skipped };
  }

  /**
   * Reaches women who used to buy and stopped.
   *
   * `at_risk` and `lapsed` are addressed separately because they want
   * different things said to them — the first is a reminder, the second is a
   * reason to come back — and the caller chooses which. At most one message a
   * month either way.
   */
  async winBack(
    stage: Extract<LifecycleStage, 'at_risk' | 'lapsed'>,
    limit = DEFAULT_BATCH,
    options: { minProjectedValue?: number } = {},
  ): Promise<Sent> {
    const customers = await this.targetsFor(stage, limit, options);
    const month = new Date().toISOString().slice(0, 7);

    let reached = 0;
    let skipped = 0;

    for (const customer of customers) {
      const claimed = await this.touch(
        customer.userId,
        ReengagementKind.WIN_BACK,
        `${stage}:${month}`,
        stage,
      );
      if (!claimed) {
        skipped += 1;
        continue;
      }

      const copy =
        stage === 'at_risk'
          ? {
              title: 'وصلتنا قطع جديدة',
              body: 'اخترنا لك ما يشبه ما اشتريتِه سابقاً.',
            }
          : {
              title: 'اشتقنا لك',
              body: 'مرّت فترة — تعالي شوفي الجديد في ريم.',
            };

      try {
        await this.notifications.dispatch('system', {
          user_ids: [customer.userId],
          channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH],
          type: NotificationType.promo,
          title: copy.title,
          body: copy.body,
          payload: { deep_link: '/', kind: 'win_back', stage },
          category: NotificationCategory.MARKETING,
        });
        reached += 1;
      } catch (error) {
        this.logger.warn(
          `Win-back not sent to ${customer.userId}: ${String(error)}`,
        );
      }
    }

    return { reached, skipped };
  }

  /**
   * Who to actually reach, in priority order.
   *
   * The lifecycle stage says *when* she went quiet; the churn reading says
   * whether that silence is unusual for her. Both are needed, and the second
   * is the one that stops the campaign wasting itself: a woman who has always
   * bought twice a year sits in `lapsed` by the calendar and is behaving
   * exactly as she always has, and an offer that treats her as a defector is
   * both a wasted discount and slightly insulting.
   *
   * When no profile exists — she has never been scored — she is still
   * included. Absence of a reading is not evidence she is fine, and excluding
   * the unscored would quietly shrink every campaign to whoever the sweep
   * happened to reach.
   *
   * `minProjectedValue` is what makes the budget go where it earns: a
   * retention offer spread evenly across everyone who might leave is spent
   * mostly on customers who were never worth much.
   */
  private async targetsFor(
    stage: Extract<LifecycleStage, 'at_risk' | 'lapsed'>,
    limit: number,
    options: { minProjectedValue?: number },
  ) {
    const customers = await this.segments.stage(stage, limit * 3);
    if (customers.length === 0) return [];

    const profiles = await this.prisma.customerProfile.findMany({
      where: { userId: { in: customers.map((c) => c.userId) } },
      select: {
        userId: true,
        churnScore: true,
        churnBand: true,
        projectedValue: true,
      },
    });
    const byUser = new Map(profiles.map((p) => [p.userId, p]));

    return customers
      .filter((customer) => {
        const profile = byUser.get(customer.userId);
        if (!profile) return true;

        // Silence that is normal for her is not churn.
        if (profile.churnBand === 'safe') return false;

        if (options.minProjectedValue !== undefined) {
          return Number(profile.projectedValue) >= options.minProjectedValue;
        }
        return true;
      })
      // Worth the most first, so a bounded run reaches the customers whose
      // leaving costs most.
      .sort((a, b) => {
        const left = Number(byUser.get(b.userId)?.projectedValue ?? 0);
        const right = Number(byUser.get(a.userId)?.projectedValue ?? 0);
        return left - right;
      })
      .slice(0, limit);
  }

  /**
   * Marks the touches that were followed by a purchase.
   *
   * Attribution is deliberately blunt: an order placed after a touch and
   * before the next one. It does not claim the message *caused* the order —
   * nothing short of a holdout group can claim that, and pretending otherwise
   * would make every campaign look like a triumph. What it answers is the
   * question a merchandiser can actually act on: of the women we reminded,
   * how many came back.
   */
  async attribute(withinDays = 7): Promise<{ converted: number }> {
    const since = new Date(Date.now() - withinDays * 24 * 60 * 60 * 1000);

    const open = await this.prisma.reengagementTouch.findMany({
      where: { convertedAt: null, sentAt: { gte: since } },
      select: { id: true, userId: true, sentAt: true },
      take: 5000,
    });

    let converted = 0;
    for (const touch of open) {
      const order = await this.prisma.order.findFirst({
        where: { userId: touch.userId, createdAt: { gt: touch.sentAt } },
        select: { createdAt: true },
        orderBy: { createdAt: 'asc' },
      });
      if (!order) continue;

      await this.prisma.reengagementTouch.update({
        where: { id: touch.id },
        data: { convertedAt: order.createdAt },
      });
      converted += 1;
    }

    return { converted };
  }

  /** What the reminders have been doing, by kind. */
  async report(days = 30) {
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const rows = await this.prisma.reengagementTouch.groupBy({
      by: ['kind'],
      where: { sentAt: { gte: since } },
      _count: { _all: true },
    });

    const converted = await this.prisma.reengagementTouch.groupBy({
      by: ['kind'],
      where: { sentAt: { gte: since }, convertedAt: { not: null } },
      _count: { _all: true },
    });
    const convertedBy = new Map(
      converted.map((row) => [row.kind, row._count._all]),
    );

    return rows.map((row) => {
      const sent = row._count._all;
      const back = convertedBy.get(row.kind) ?? 0;
      return {
        kind: row.kind.toLowerCase(),
        sent,
        returned: back,
        // Null rather than 0 when nothing was sent: "no rate" and "a rate of
        // zero" are different statements about a campaign.
        return_rate: sent > 0 ? Number((back / sent).toFixed(4)) : null,
      };
    });
  }

  /**
   * Claims the right to send one message.
   *
   * Written before the send, not after, and the unique key does the work: two
   * jobs racing on the same basket both try to insert, one wins, and the loser
   * reads the conflict as "already reminded" rather than sending a second
   * copy. Doing this after the send would leave a crash in between as a
   * licence to send again.
   */
  private async touch(
    userId: string,
    kind: ReengagementKind,
    reference: string,
    stage: string,
  ): Promise<boolean> {
    try {
      await this.prisma.reengagementTouch.create({
        data: { userId, kind, reference, stage },
      });
      return true;
    } catch {
      return false;
    }
  }
}
