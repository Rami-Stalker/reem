import { Injectable } from '@nestjs/common';
import {
  NotificationCategory,
  NotificationDeliveryStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { utcCast, utcParam } from '../../common/sql/utc-timestamp';
import { PLATFORM_TIMEZONE } from '../customer-intelligence/customer-facts.service';

/**
 * How much the platform may say, and when.
 *
 * These are the numbers that decide whether Reem is useful or is the app she
 * turns notifications off for — which is a decision she makes once, silently,
 * and never revisits. They are set low on purpose.
 */
export const CONTACT_LIMITS = {
  /** Marketing messages in a rolling day. */
  perDay: 1,
  /** And in a rolling week. Two a week is a shop; six is a nuisance. */
  perWeek: 3,
  /**
   * Local hours during which nothing marketing is sent.
   *
   * A push at two in the morning is not a message, it is an intrusion, and no
   * conversion rate justifies it. Transactional messages ignore this — a woman
   * whose order is out for delivery wants to know at seven.
   */
  quietFrom: 22,
  quietUntil: 9,
} as const;

export type ContactDecision =
  | { allowed: true }
  | { allowed: false; reason: string; ar: string };

/**
 * The single gate every marketing message passes through.
 *
 * Placed here rather than in each campaign because the failure it prevents is
 * cumulative: an abandoned-basket reminder, a win-back, a price drop and a
 * flash-sale announcement are each defensible on their own, and four of them
 * on a Tuesday is the reason she stops opening the app. No individual sender
 * can see the total; this can.
 */
@Injectable()
export class ContactPolicyService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Whether the platform may send her a marketing message right now.
   *
   * Transactional messages are not asked about at all — see the enum. Callers
   * that pass `TRANSACTIONAL` get `allowed` unconditionally, which is
   * deliberate rather than an oversight: the day someone caps an order update
   * is the day a customer stops trusting the app to tell her anything.
   */
  async mayContact(
    userId: string,
    options: {
      category: NotificationCategory;
      now?: Date;
      /** Skip the clock check — for a caller that has already scheduled. */
      ignoreQuietHours?: boolean;
    },
  ): Promise<ContactDecision> {
    if (options.category === NotificationCategory.TRANSACTIONAL) {
      return { allowed: true };
    }

    const now = options.now ?? new Date();

    if (!options.ignoreQuietHours && (await this.isQuiet(now))) {
      return {
        allowed: false,
        reason: 'quiet_hours',
        ar: 'خارج ساعات التواصل — لا تُرسل رسائل ترويجية ليلاً',
      };
    }

    // Her own preference comes before any cap. A woman who turned push off
    // has already answered this question.
    const preference = await this.prisma.notificationPreference.findUnique({
      where: { userId },
      select: { push: true },
    });
    if (preference && !preference.push) {
      return {
        allowed: false,
        reason: 'push_disabled',
        ar: 'أوقفت الإشعارات',
      };
    }

    const [today, week] = await Promise.all([
      this.marketingSince(userId, new Date(now.getTime() - 24 * 3600_000)),
      this.marketingSince(userId, new Date(now.getTime() - 7 * 24 * 3600_000)),
    ]);

    if (today >= CONTACT_LIMITS.perDay) {
      return {
        allowed: false,
        reason: 'daily_cap',
        ar: `بلغت الحدّ اليومي (${CONTACT_LIMITS.perDay})`,
      };
    }
    if (week >= CONTACT_LIMITS.perWeek) {
      return {
        allowed: false,
        reason: 'weekly_cap',
        ar: `بلغت الحدّ الأسبوعي (${CONTACT_LIMITS.perWeek})`,
      };
    }

    return { allowed: true };
  }

  /**
   * How many marketing messages she has had, for a screen that has to explain
   * why a campaign reached fewer people than its audience.
   */
  async recentLoad(userId: string, now = new Date()) {
    const [today, week] = await Promise.all([
      this.marketingSince(userId, new Date(now.getTime() - 24 * 3600_000)),
      this.marketingSince(userId, new Date(now.getTime() - 7 * 24 * 3600_000)),
    ]);
    return {
      last_day: today,
      last_week: week,
      day_limit: CONTACT_LIMITS.perDay,
      week_limit: CONTACT_LIMITS.perWeek,
    };
  }

  /**
   * When she should next be reached, given what is known about her.
   *
   * Her own best hour when the profile has enough observations behind it,
   * otherwise the first hour outside quiet time. Returns a Date so a caller
   * schedules rather than guessing, and never returns a time in the past.
   */
  async nextWindow(userId: string, now = new Date()): Promise<Date> {
    const profile = await this.prisma.customerProfile.findUnique({
      where: { userId },
      select: { bestContactHour: true },
    });

    const localHour = await this.localHour(now);
    const target =
      profile?.bestContactHour !== null && profile?.bestContactHour !== undefined
        ? profile.bestContactHour
        : CONTACT_LIMITS.quietUntil;

    // Hours forward from now to the target, in local terms, wrapped to
    // tomorrow when it has already passed today.
    let ahead = target - localHour;
    if (ahead <= 0) ahead += 24;

    return new Date(now.getTime() + ahead * 3600_000);
  }

  // ── internals ────────────────────────────────────────────────────────────

  private async marketingSince(userId: string, since: Date): Promise<number> {
    return this.prisma.notificationDelivery.count({
      where: {
        userId,
        category: NotificationCategory.MARKETING,
        // Queued counts too: a message waiting to go out is a message she is
        // about to receive, and not counting it lets a burst of scheduling
        // slip past the cap entirely.
        status: {
          in: [
            NotificationDeliveryStatus.SENT,
            NotificationDeliveryStatus.QUEUED,
          ],
        },
        OR: [{ sentAt: { gte: since } }, { createdAt: { gte: since } }],
      },
    });
  }

  private async isQuiet(now: Date): Promise<boolean> {
    const hour = await this.localHour(now);
    // The window wraps midnight, so the test is a union rather than a range.
    return hour >= CONTACT_LIMITS.quietFrom || hour < CONTACT_LIMITS.quietUntil;
  }

  /**
   * The hour it is where her customers are.
   *
   * Asked of the database rather than computed in Node, so the answer uses the
   * same timezone rules — including the ones that change — as everything else
   * that reads a local hour. A server running in UTC would otherwise send the
   * evening batch at lunchtime.
   */
  private async localHour(now: Date): Promise<number> {
    const rows = await this.prisma.$queryRawUnsafe<{ hour: number }[]>(
      `SELECT extract(hour FROM (${utcCast('$1')} AT TIME ZONE 'UTC' AT TIME ZONE $2))::int AS hour`,
      utcParam(now),
      PLATFORM_TIMEZONE,
    );
    return rows[0]?.hour ?? now.getUTCHours();
  }
}
