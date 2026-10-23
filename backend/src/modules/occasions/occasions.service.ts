import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  NotificationCategory,
  NotificationChannel,
  NotificationType,
  OccasionKind,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { LOOK_INCLUDE } from '../closet/looks/closet-look.service';
import { NotificationsService } from '../notifications/notifications.service';
import { parseLocalDate } from '../salons/salon-hours';
import {
  MAX_DAYS_AHEAD,
  MAX_DAYS_BACK,
  OccasionOutfit,
  RepeatWarning,
  REMINDER_STAGES,
  addDays,
  circleKeyOf,
  dateFromKey,
  dateKey,
  daysBetween,
  dueStage,
  findRepeats,
  isManualStep,
  localDate,
  nextStep,
  planSteps,
  reminderCopy,
  shouldRemind,
  withinSendingHours,
} from './occasion-plan';

export const OCCASION_INCLUDE = {
  look: { include: LOOK_INCLUDE },
  appointment: { include: { salon: true } },
} satisfies Prisma.OccasionInclude;

export type OccasionRecord = Prisma.OccasionGetPayload<{
  include: typeof OCCASION_INCLUDE;
}>;

export interface OccasionInput {
  title: string;
  kind: OccasionKind;
  date: string;
  startsAtTime?: string | null;
  location?: string | null;
  circle?: string | null;
  note?: string | null;
  lookId?: string | null;
  appointmentId?: string | null;
  remindersEnabled?: boolean;
}

/** `undefined` leaves a field alone; `null` clears it. */
export type OccasionPatch = Partial<OccasionInput>;

/**
 * «مناسباتي» — her calendar of days worth getting ready for.
 *
 * The service is mostly validation and plumbing; the decisions live in
 * `occasion-plan.ts`, where they can be tested without a database. What only
 * this file can do is make the two links trustworthy: a look must be one she
 * built and an appointment one she booked. Without those two checks an
 * occasion would be a way to read somebody else's wardrobe or calendar by id.
 */
@Injectable()
export class OccasionsService {
  private readonly logger = new Logger(OccasionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly config: ConfigService,
  ) {}

  /**
   * Her local offset. The same setting the salon calendar reads: an occasion
   * and the appointment booked for it must agree about which day "Thursday"
   * is.
   */
  private get offset(): number {
    return this.config.get<number>('salons.utcOffsetMinutes') ?? 180;
  }

  /** Today, `YYYY-MM-DD`, in her reckoning. */
  today(now: Date = new Date()): string {
    return localDate(now, this.offset);
  }

  // ── Reading ───────────────────────────────────────────────────────────

  /**
   * Upcoming ascending — the next one first, because that is the one she is
   * getting ready for — and past descending.
   */
  async list(userId: string, scope: 'upcoming' | 'past' = 'upcoming'): Promise<OccasionRecord[]> {
    const today = dateFromKey(this.today());
    return this.prisma.occasion.findMany({
      where: {
        userId,
        date: scope === 'upcoming' ? { gte: today } : { lt: today },
      },
      include: OCCASION_INCLUDE,
      orderBy: [{ date: scope === 'upcoming' ? 'asc' : 'desc' }, { createdAt: 'asc' }],
      take: scope === 'upcoming' ? 100 : 50,
    });
  }

  async require(userId: string, id: string): Promise<OccasionRecord> {
    const occasion = await this.prisma.occasion.findFirst({
      where: { id, userId },
      include: OCCASION_INCLUDE,
    });
    if (!occasion) throw new NotFoundException('Occasion not found');
    return occasion;
  }

  /**
   * «ما لبستيه قدّامهم» for one occasion.
   *
   * One query for every other occasion she shares this circle with, then the
   * comparison in `findRepeats`. Only asked on the detail page: it is the one
   * place the answer is read, and the list does not need to pay for it.
   */
  async repeatsFor(occasion: OccasionRecord): Promise<RepeatWarning[]> {
    if (!occasion.circleKey || !occasion.lookId) return [];

    const others = await this.prisma.occasion.findMany({
      where: {
        userId: occasion.userId,
        circleKey: occasion.circleKey,
        lookId: { not: null },
        id: { not: occasion.id },
      },
      include: {
        look: {
          select: {
            items: {
              select: {
                closetItem: { select: { id: true, title: true, slot: true } },
              },
            },
          },
        },
      },
      orderBy: { date: 'desc' },
      take: 100,
    });

    const outfitOf = (row: {
      id: string;
      title: string;
      date: Date;
      lookId: string | null;
      circleKey: string | null;
      look: { items: { closetItem: { id: string; title: string; slot: OccasionOutfit['pieces'][number]['slot'] } | null }[] } | null;
    }): OccasionOutfit => ({
      id: row.id,
      title: row.title,
      date: dateKey(row.date),
      lookId: row.lookId,
      circleKey: row.circleKey,
      pieces: (row.look?.items ?? [])
        .map((item) => item.closetItem)
        .filter((piece): piece is NonNullable<typeof piece> => !!piece),
    });

    return findRepeats(outfitOf(occasion), others.map(outfitOf), this.today());
  }

  // ── Writing ───────────────────────────────────────────────────────────

  async create(userId: string, input: OccasionInput): Promise<OccasionRecord> {
    const title = this.title(input.title);
    const date = this.date(input.date);
    if (input.lookId) await this.assertLook(userId, input.lookId);
    if (input.appointmentId) await this.assertAppointment(userId, input.appointmentId);

    const occasion = await this.prisma.occasion.create({
      data: {
        userId,
        title,
        kind: input.kind,
        date: dateFromKey(date),
        startsAtTime: input.startsAtTime ?? null,
        location: this.text(input.location),
        circle: this.text(input.circle),
        circleKey: circleKeyOf(input.circle),
        note: this.text(input.note),
        lookId: input.lookId ?? null,
        appointmentId: input.appointmentId ?? null,
        remindersEnabled: input.remindersEnabled ?? true,
        doneSteps: [],
        lastReminderStage: dueStage(daysBetween(this.today(), date)),
      },
    });
    return this.require(userId, occasion.id);
  }

  async update(userId: string, id: string, patch: OccasionPatch): Promise<OccasionRecord> {
    const current = await this.require(userId, id);

    const data: Prisma.OccasionUncheckedUpdateInput = {};
    if (patch.title !== undefined) data.title = this.title(patch.title);
    if (patch.kind !== undefined) data.kind = patch.kind;
    if (patch.startsAtTime !== undefined) data.startsAtTime = patch.startsAtTime;
    if (patch.location !== undefined) data.location = this.text(patch.location);
    if (patch.note !== undefined) data.note = this.text(patch.note);
    if (patch.remindersEnabled !== undefined) data.remindersEnabled = patch.remindersEnabled;
    if (patch.circle !== undefined) {
      data.circle = this.text(patch.circle);
      data.circleKey = circleKeyOf(patch.circle);
    }

    if (patch.date !== undefined) {
      const date = this.date(patch.date);
      if (date !== dateKey(current.date)) {
        data.date = dateFromKey(date);
        // A new day is a new countdown. Restarted from the stage the new date
        // is already in, for the same reason as on create.
        data.lastReminderStage = dueStage(daysBetween(this.today(), date));
      }
    }

    if (patch.lookId !== undefined) {
      if (patch.lookId) await this.assertLook(userId, patch.lookId);
      data.lookId = patch.lookId;
    }
    if (patch.appointmentId !== undefined) {
      if (patch.appointmentId) await this.assertAppointment(userId, patch.appointmentId);
      data.appointmentId = patch.appointmentId;
    }

    await this.prisma.occasion.update({ where: { id }, data });
    return this.require(userId, id);
  }

  /** Tick or untick a step only she can see — the gift. */
  async setStep(userId: string, id: string, key: string, done: boolean): Promise<OccasionRecord> {
    if (!isManualStep(key)) {
      // The rest are read from the look and the appointment. Letting her tick
      // "salon booked" by hand would make the plan say something the
      // appointments table does not.
      throw new BadRequestException(`Step ${key} cannot be ticked by hand`);
    }
    const current = await this.require(userId, id);
    const steps = new Set(current.doneSteps);
    if (done) steps.add(key);
    else steps.delete(key);

    await this.prisma.occasion.update({
      where: { id },
      data: { doneSteps: [...steps] },
    });
    return this.require(userId, id);
  }

  async remove(userId: string, id: string): Promise<void> {
    await this.require(userId, id);
    await this.prisma.occasion.delete({ where: { id } });
  }

  // ── The countdown ─────────────────────────────────────────────────────

  /**
   * Ring every occasion that has reached a countdown mark.
   *
   * Idempotent in the way the salon reminder is: the stage is claimed with a
   * conditional update *before* the notification goes out, and only the
   * update that matched a row sends. Two overlapping passes — a catch-up run
   * and the hourly tick — cannot both ring her for the same mark.
   *
   * Outside the sending hours it does nothing and leaves the mark unclaimed,
   * so the next pass inside them picks it up.
   */
  async sendDueReminders(now: Date = new Date()): Promise<number> {
    if (!withinSendingHours(now, this.offset)) return 0;

    const today = this.today(now);
    const horizon = Math.max(...REMINDER_STAGES);
    const due = await this.prisma.occasion.findMany({
      where: {
        remindersEnabled: true,
        date: { gte: dateFromKey(today), lte: dateFromKey(addDays(today, horizon)) },
      },
      include: {
        look: { select: { items: { select: { closetItemId: true } } } },
        appointment: { select: { status: true } },
      },
      take: 500,
    });

    let sent = 0;
    for (const occasion of due) {
      const daysLeft = daysBetween(today, dateKey(occasion.date));
      const stage = shouldRemind(daysLeft, occasion.lastReminderStage);
      if (stage === null) continue;

      const claimed = await this.prisma.occasion.updateMany({
        where: {
          id: occasion.id,
          remindersEnabled: true,
          OR: [{ lastReminderStage: null }, { lastReminderStage: { gt: stage } }],
        },
        data: { lastReminderStage: stage },
      });
      if (claimed.count === 0) continue;

      const steps = planSteps({
        kind: occasion.kind,
        daysLeft,
        look: occasion.look
          ? { missingCount: occasion.look.items.filter((item) => !item.closetItemId).length }
          : null,
        appointment: occasion.appointment,
        doneSteps: occasion.doneSteps,
      });
      await this.notify(occasion.userId, occasion.id, reminderCopy(occasion.title, daysLeft, nextStep(steps)));
      sent += 1;
    }
    return sent;
  }

  // ── Guards ────────────────────────────────────────────────────────────

  private title(value: string): string {
    const title = value.trim();
    if (!title) throw new BadRequestException('Title is required');
    return title;
  }

  private text(value: string | null | undefined): string | null {
    const text = value?.trim();
    return text ? text : null;
  }

  /** A real calendar day, and not a mistyped year. */
  private date(value: string): string {
    if (!parseLocalDate(value)) throw new BadRequestException('Invalid date');
    const offset = daysBetween(this.today(), value);
    if (offset < -MAX_DAYS_BACK || offset > MAX_DAYS_AHEAD) {
      throw new BadRequestException('Date is out of range');
    }
    return value;
  }

  /** Her look, or a 400. Archived looks count: she may plan an old favourite. */
  private async assertLook(userId: string, lookId: string): Promise<void> {
    const found = await this.prisma.closetLook.count({ where: { id: lookId, userId } });
    if (!found) throw new BadRequestException('That look is not in your closet');
  }

  /** Her booking, or a 400. Never a booking at her salon by somebody else. */
  private async assertAppointment(userId: string, appointmentId: string): Promise<void> {
    const found = await this.prisma.appointment.count({
      where: { id: appointmentId, customerId: userId },
    });
    if (!found) throw new BadRequestException('That appointment is not yours');
  }

  /**
   * One countdown, to one woman.
   *
   * TRANSACTIONAL, because she asked for it by writing the day down — and
   * `withinSendingHours` above is what keeps that from meaning "at any hour".
   * Failures are swallowed: the mark is already claimed, and a transport that
   * is down must not fail the sweep for everyone after her.
   */
  private async notify(
    userId: string,
    occasionId: string,
    message: { title: string; body: string },
  ): Promise<void> {
    try {
      await this.notifications.dispatch(userId, {
        user_ids: [userId],
        channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH],
        type: NotificationType.occasion,
        title: message.title,
        body: message.body,
        payload: { occasion_id: occasionId },
        category: NotificationCategory.TRANSACTIONAL,
      });
    } catch (error) {
      this.logger.warn(`Occasion reminder failed: ${(error as Error).message}`);
    }
  }
}
