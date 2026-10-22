import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppointmentStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  candidateStarts,
  instantAt,
  localDateOf,
  openWindows,
  overlaps,
  parseLocalDate,
  timeOfDay,
  weekdayOf,
} from './salon-hours';

/**
 * The statuses that occupy a chair.
 *
 * PENDING counts. A request the salon has not answered yet still holds the
 * slot — otherwise two women both "request" six o'clock, both are told it is
 * free, and the salon has to disappoint one of them by hand. CANCELLED,
 * COMPLETED and NO_SHOW release it.
 */
export const LIVE_APPOINTMENT_STATUSES: AppointmentStatus[] = [
  AppointmentStatus.PENDING,
  AppointmentStatus.CONFIRMED,
];

export interface AvailableSlot {
  /** `18:00`, in the salon's own reckoning — what the customer reads. */
  time: string;
  /** The same moment as an instant, which is what she books with. */
  startsAt: Date;
  endsAt: Date;
}

/**
 * When a salon can actually see her.
 *
 * ## Why this is its own service
 *
 * Two callers need the same answer and must never disagree about it: the day
 * view the customer picks from, and the booking itself. If the booking
 * recomputed availability its own way, a slot could be offered and then
 * refused — which reads as a broken app rather than as a busy salon. So the
 * grid is built here, once, and `AppointmentsService` asks this for the window
 * before it takes the lock.
 *
 * ## What makes a slot unavailable
 *
 * Five things, and each is a real fact rather than a heuristic:
 *
 *  1. The salon is closed that weekday, or shut that date.
 *  2. The service would not *finish* before closing.
 *  3. It starts sooner than `leadMinutes` from now, or beyond `horizonDays`.
 *  4. The salon is already serving `concurrentCapacity` women across it.
 *  5. The service is not offered at that location (in salon / at home).
 */
@Injectable()
export class SalonAvailabilityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  get offsetMinutes(): number {
    return this.config.get<number>('salons.utcOffsetMinutes') ?? 180;
  }

  /** The salon's own `YYYY-MM-DD` for an instant. */
  localDate(instant: Date): string {
    return localDateOf(instant, this.offsetMinutes);
  }

  /**
   * Free start times for one service on one local date.
   *
   * Returns an empty list rather than throwing for a closed day, a date in the
   * past or a date beyond the horizon: "nothing free" is the honest answer to
   * all three, and a day picker that throws on a Friday is a day picker nobody
   * can use.
   */
  async slotsFor(
    salonId: string,
    serviceId: string,
    date: string,
    now: Date = new Date(),
  ): Promise<AvailableSlot[]> {
    const parsed = parseLocalDate(date);
    if (!parsed) return [];

    const salon = await this.prisma.salon.findUnique({
      where: { id: salonId },
      select: {
        id: true,
        slotMinutes: true,
        leadMinutes: true,
        horizonDays: true,
        concurrentCapacity: true,
      },
    });
    if (!salon) return [];

    const service = await this.prisma.salonService.findFirst({
      where: { id: serviceId, salonId, isActive: true },
      select: { durationMinutes: true, bufferMinutes: true },
    });
    if (!service) return [];

    const [hours, closure] = await Promise.all([
      this.prisma.salonWorkingHours.findUnique({
        where: {
          salonId_weekday: { salonId, weekday: weekdayOf(parsed) },
        },
      }),
      this.prisma.salonClosure.findUnique({
        where: {
          salonId_date: {
            salonId,
            // A `@db.Date` column compares at midnight UTC; the local date is
            // the key, so it is built as midnight UTC on purpose and not
            // shifted by the salon's offset.
            date: new Date(`${date}T00:00:00.000Z`),
          },
        },
        select: { id: true },
      }),
    ]);
    if (closure) return [];

    const windows = openWindows(hours);
    if (windows.length === 0) return [];

    // The whole booking occupies duration + buffer: the next woman cannot sit
    // down while the chair is being cleaned.
    const occupied = service.durationMinutes + service.bufferMinutes;
    const starts = candidateStarts(windows, salon.slotMinutes, occupied);
    if (starts.length === 0) return [];

    const earliest = new Date(now.getTime() + salon.leadMinutes * 60_000);
    const latest = new Date(now.getTime() + salon.horizonDays * 86_400_000);

    const dayFrom = instantAt(parsed, 0, this.offsetMinutes);
    const dayTo = instantAt(parsed, 24 * 60, this.offsetMinutes);

    const taken = await this.bookedWindows(salonId, dayFrom, dayTo);

    const free: AvailableSlot[] = [];
    for (const minute of starts) {
      const startsAt = instantAt(parsed, minute, this.offsetMinutes);
      if (startsAt < earliest || startsAt > latest) continue;

      const endsAt = new Date(startsAt.getTime() + occupied * 60_000);
      const concurrent = taken.filter((booking) =>
        overlaps(
          startsAt.getTime(),
          endsAt.getTime(),
          booking.startsAt.getTime(),
          booking.endsAt.getTime(),
        ),
      ).length;
      if (concurrent >= salon.concurrentCapacity) continue;

      free.push({ time: timeOfDay(minute), startsAt, endsAt });
    }
    return free;
  }

  /**
   * How many live appointments overlap [startsAt, endsAt).
   *
   * Takes an optional transaction so the booking path can ask it *inside* the
   * lock. Asking it outside would be the race this whole design exists to
   * close.
   */
  async concurrentAt(
    salonId: string,
    startsAt: Date,
    endsAt: Date,
    tx?: Prisma.TransactionClient,
  ): Promise<number> {
    const db = tx ?? this.prisma;
    return db.appointment.count({
      where: {
        salonId,
        status: { in: LIVE_APPOINTMENT_STATUSES },
        // Half-open overlap. `startsAt < end AND endsAt > start` is the whole
        // predicate, and the (salon_id, starts_at, ends_at) index serves it.
        startsAt: { lt: endsAt },
        endsAt: { gt: startsAt },
      },
    });
  }

  /** Live bookings inside a day, for the grid above. */
  private async bookedWindows(salonId: string, from: Date, to: Date) {
    return this.prisma.appointment.findMany({
      where: {
        salonId,
        status: { in: LIVE_APPOINTMENT_STATUSES },
        startsAt: { lt: to },
        endsAt: { gt: from },
      },
      select: { startsAt: true, endsAt: true },
    });
  }

  /**
   * The next few days that have anything free, for the day strip on the salon
   * page.
   *
   * Bounded by `days` rather than by the salon's whole horizon: a month of
   * empty-day queries to draw a one-week strip is thirty round trips for six
   * answers nobody asked for.
   */
  async openDays(
    salonId: string,
    serviceId: string,
    days: number,
    now: Date = new Date(),
  ): Promise<{ date: string; slots: number }[]> {
    const out: { date: string; slots: number }[] = [];
    for (let offset = 0; offset < days; offset += 1) {
      const date = localDateOf(
        new Date(now.getTime() + offset * 86_400_000),
        this.offsetMinutes,
      );
      const slots = await this.slotsFor(salonId, serviceId, date, now);
      out.push({ date, slots: slots.length });
    }
    return out;
  }
}
