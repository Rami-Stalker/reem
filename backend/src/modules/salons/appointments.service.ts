import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomBytes } from 'node:crypto';
import {
  AppointmentActor,
  AppointmentStatus,
  NotificationCategory,
  NotificationChannel,
  NotificationType,
  Prisma,
  SalonServiceLocation,
  SalonStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { buildMeta } from '../../common/dto/pagination.dto';
import { NotificationsService } from '../notifications/notifications.service';
import {
  AppointmentQueryDto,
  CancelAppointmentDto,
  CreateAppointmentDto,
  ReviewAppointmentDto,
  SalonNoteDto,
} from './dto/salons.dto';
import {
  LIVE_APPOINTMENT_STATUSES,
  SalonAvailabilityService,
} from './salon-availability.service';
import {
  serializeAppointment,
  serializeSalonReview,
} from './salons.serializer';

/** What a customer may see on her own booking's salon card. */
const SALON_CARD_INCLUDE = {
  salon: true,
  address: true,
  review: true,
} satisfies Prisma.AppointmentInclude;

/**
 * Booking, and everything that happens to a booking afterwards.
 *
 * ## The invariant
 *
 * **A slot cannot be sold twice.** Everything else here is bookkeeping; this is
 * the part that has to be right, and it is the part that is easy to get wrong
 * in a way nobody notices until two women are standing in the same salon at
 * six o'clock.
 *
 * It cannot be a unique index. Services have different durations, so "the same
 * slot" is an *overlap* between two half-open intervals rather than an equal
 * start time — and a salon with three chairs may legitimately serve three
 * women at once. So the rule is: inside a transaction, take a `FOR UPDATE`
 * lock on the salon row, count the live appointments overlapping the requested
 * window, and admit the booking only if that count is below the salon's
 * capacity.
 *
 * The lock is on the **salon**, not on the appointments. Two women booking
 * different salons never contend; two women booking the same salon are
 * serialised for the microseconds the count takes, which the
 * `(salon_id, starts_at, ends_at)` index makes cheap. This is the same
 * read-then-write discipline `WalletService` and `CouponsService` already use,
 * and `salons.integration.spec.ts` proves it by racing two bookings at the
 * same second against real Postgres.
 *
 * ## No money
 *
 * An appointment is a reservation, paid at the chair. There is no ledger
 * entry, no escrow, no commission and no order. The price is frozen on the row
 * only so a salon raising its prices on Tuesday does not reprice Thursday.
 */
@Injectable()
export class AppointmentsService {
  private readonly logger = new Logger(AppointmentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly availability: SalonAvailabilityService,
    private readonly notifications: NotificationsService,
    private readonly config: ConfigService,
  ) {}

  // ── Booking ──────────────────────────────────────────────────────────────

  async book(user: AuthUser, salonId: string, dto: CreateAppointmentDto) {
    const startsAt = new Date(dto.starts_at);
    if (Number.isNaN(startsAt.getTime())) {
      throw new BadRequestException('starts_at must be an ISO instant');
    }

    const salon = await this.prisma.salon.findUnique({
      where: { id: salonId },
      select: {
        id: true,
        ownerId: true,
        name: true,
        status: true,
        leadMinutes: true,
        horizonDays: true,
        concurrentCapacity: true,
        homeService: true,
      },
    });
    if (!salon || salon.status !== SalonStatus.ACTIVE) {
      throw new NotFoundException('Salon not found');
    }

    const service = await this.prisma.salonService.findFirst({
      where: { id: dto.service_id, salonId, isActive: true },
    });
    if (!service) throw new NotFoundException('Service not found');

    const atHome = dto.at_home ?? false;
    this.assertLocationAllowed(service.location, atHome, salon.homeService);

    // Her own address, and only for a home visit. Checked here rather than
    // trusted from the client: an address id is a foreign key into another
    // woman's address book.
    let addressId: string | null = null;
    if (atHome) {
      if (!dto.address_id) {
        throw new BadRequestException('A home appointment needs an address');
      }
      const address = await this.prisma.address.findFirst({
        where: { id: dto.address_id, userId: user.id },
        select: { id: true },
      });
      if (!address) throw new NotFoundException('Address not found');
      addressId = address.id;
    }

    const occupied = service.durationMinutes + service.bufferMinutes;
    const endsAt = new Date(startsAt.getTime() + occupied * 60_000);
    const now = new Date();

    if (startsAt.getTime() < now.getTime() + salon.leadMinutes * 60_000) {
      throw new BadRequestException('That time is too soon to book');
    }
    if (startsAt.getTime() > now.getTime() + salon.horizonDays * 86_400_000) {
      throw new BadRequestException('That date is beyond the salon’s calendar');
    }

    // The slot has to be one the salon actually offers — inside opening hours,
    // on the grid, not on a closure. Asked of the same service the day view
    // asks, so a time she was offered is a time she can book.
    const date = this.availability.localDate(startsAt);
    const offered = await this.availability.slotsFor(
      salonId,
      service.id,
      date,
      now,
    );
    if (!offered.some((slot) => slot.startsAt.getTime() === startsAt.getTime())) {
      throw new ConflictException('That time is no longer available');
    }

    const appointment = await this.prisma.$transaction(async (tx) => {
      // ── The lock ──────────────────────────────────────────────────────
      //
      // Serialises bookings for *this* salon and no other. Everything below
      // it runs with the guarantee that no second booking can be counting the
      // same window at the same time.
      await tx.$queryRaw`SELECT id FROM salons WHERE id = ${salonId}::uuid FOR UPDATE`;

      const concurrent = await this.availability.concurrentAt(
        salonId,
        startsAt,
        endsAt,
        tx,
      );
      if (concurrent >= salon.concurrentCapacity) {
        throw new ConflictException('That time has just been taken');
      }

      // One live booking per woman per slot, so a double tap on a slow
      // connection does not produce two appointments at six o'clock.
      const hers = await tx.appointment.count({
        where: {
          customerId: user.id,
          status: { in: LIVE_APPOINTMENT_STATUSES },
          startsAt: { lt: endsAt },
          endsAt: { gt: startsAt },
        },
      });
      if (hers > 0) {
        throw new ConflictException('You already have a booking at that time');
      }

      return tx.appointment.create({
        data: {
          reference: this.reference(),
          salonId,
          customerId: user.id,
          serviceId: service.id,
          startsAt,
          endsAt,
          serviceName: service.name,
          durationMinutes: service.durationMinutes,
          price: service.price,
          currency: service.currency,
          atHome,
          addressId,
          customerNote: dto.note?.trim() || null,
        },
        include: SALON_CARD_INCLUDE,
      });
    });

    await this.prisma.salon.update({
      where: { id: salonId },
      data: { appointmentsCount: { increment: 1 } },
    });

    // The salon is told, not the customer: she is looking at the screen that
    // just confirmed it, and a push about a thing she did a second ago is
    // noise. She hears from us when the salon answers.
    await this.notify(salon.ownerId, {
      title: 'طلب حجز جديد',
      body: `${appointment.serviceName} — ${this.when(appointment.startsAt)}`,
      appointmentId: appointment.id,
    });

    return serializeAppointment(appointment);
  }

  // ── Her side ─────────────────────────────────────────────────────────────

  async mine(userId: string, query: AppointmentQueryDto) {
    const where: Prisma.AppointmentWhereInput = {
      customerId: userId,
      ...this.filterWhere(query.filter),
    };

    const [rows, total] = await Promise.all([
      this.prisma.appointment.findMany({
        where,
        orderBy:
          query.filter === 'past'
            ? { startsAt: 'desc' }
            : { startsAt: 'asc' },
        skip: query.skip,
        take: query.limit,
        include: SALON_CARD_INCLUDE,
      }),
      this.prisma.appointment.count({ where }),
    ]);

    return {
      data: rows.map(serializeAppointment),
      pagination: buildMeta(query.page, query.limit, total, rows.length),
    };
  }

  /** One booking, readable by the woman who made it and the salon that has it. */
  async detail(user: AuthUser, id: string) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id },
      include: { ...SALON_CARD_INCLUDE, customer: true },
    });
    if (!appointment) throw new NotFoundException('Appointment not found');

    const isCustomer = appointment.customerId === user.id;
    const isSalon = appointment.salon.ownerId === user.id;
    if (!isCustomer && !isSalon) {
      throw new ForbiddenException('That is not your appointment');
    }

    // The customer's own copy carries no `customer` block: she knows who she
    // is, and her contact details do not belong in a payload she could hand to
    // somebody else.
    return serializeAppointment(
      isSalon ? appointment : { ...appointment, customer: null },
    );
  }

  async cancel(user: AuthUser, id: string, dto: CancelAppointmentDto) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id },
      include: { salon: true },
    });
    if (!appointment) throw new NotFoundException('Appointment not found');

    const isCustomer = appointment.customerId === user.id;
    const isSalon = appointment.salon.ownerId === user.id;
    if (!isCustomer && !isSalon) {
      throw new ForbiddenException('That is not your appointment');
    }
    if (!LIVE_APPOINTMENT_STATUSES.includes(appointment.status)) {
      throw new ConflictException('That appointment is already closed');
    }

    // Late is *recorded*, never refused. A woman who cannot come cannot come,
    // and a salon that is told at the last minute still needs to know it was
    // the last minute.
    const noticeMs = appointment.salon.cancellationHours * 3_600_000;
    const late =
      isCustomer &&
      appointment.startsAt.getTime() - Date.now() < noticeMs;

    const updated = await this.prisma.appointment.update({
      where: { id },
      data: {
        status: AppointmentStatus.CANCELLED,
        cancelledAt: new Date(),
        cancelledBy: isCustomer
          ? AppointmentActor.CUSTOMER
          : AppointmentActor.SALON,
        cancellationReason: dto.reason?.trim() || null,
        cancelledLate: late,
      },
      include: SALON_CARD_INCLUDE,
    });

    // Whoever did not press the button is the one who needs telling.
    await this.notify(
      isCustomer ? appointment.salon.ownerId : appointment.customerId,
      {
        title: isCustomer ? 'أُلغي حجز' : 'أُلغي موعدك',
        body: `${updated.serviceName} — ${this.when(updated.startsAt)}`,
        appointmentId: updated.id,
      },
    );

    return serializeAppointment(updated);
  }

  async review(user: AuthUser, id: string, dto: ReviewAppointmentDto) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id },
      include: { review: true },
    });
    if (!appointment) throw new NotFoundException('Appointment not found');
    if (appointment.customerId !== user.id) {
      throw new ForbiddenException('That is not your appointment');
    }
    // Only from a completed one, which is what makes every rating here a
    // verified one without needing a flag to claim it.
    if (appointment.status !== AppointmentStatus.COMPLETED) {
      throw new ConflictException(
        'You can review an appointment once it has been completed',
      );
    }
    if (appointment.review) {
      throw new ConflictException('You have already reviewed this appointment');
    }

    const review = await this.prisma.$transaction(async (tx) => {
      const created = await tx.salonReview.create({
        data: {
          appointmentId: appointment.id,
          salonId: appointment.salonId,
          userId: user.id,
          rating: dto.rating,
          body: dto.body?.trim() || null,
        },
        include: { user: true },
      });
      await this.refreshRating(tx, appointment.salonId);
      return created;
    });

    const salon = await this.prisma.salon.findUnique({
      where: { id: appointment.salonId },
      select: { ownerId: true },
    });
    if (salon) {
      await this.notify(salon.ownerId, {
        title: 'تقييم جديد',
        body: `${dto.rating} ★ — ${appointment.serviceName}`,
        appointmentId: appointment.id,
      });
    }

    return serializeSalonReview(review);
  }

  // ── The salon's side ─────────────────────────────────────────────────────

  async queue(user: AuthUser, salonId: string, query: AppointmentQueryDto) {
    await this.assertOwner(user, salonId);

    const where: Prisma.AppointmentWhereInput = {
      salonId,
      ...this.filterWhere(query.filter),
      ...(query.date ? this.dayWhere(query.date) : {}),
    };

    const [rows, total] = await Promise.all([
      this.prisma.appointment.findMany({
        where,
        orderBy: { startsAt: 'asc' },
        skip: query.skip,
        take: query.limit,
        include: { ...SALON_CARD_INCLUDE, customer: true },
      }),
      this.prisma.appointment.count({ where }),
    ]);

    return {
      data: rows.map(serializeAppointment),
      pagination: buildMeta(query.page, query.limit, total, rows.length),
    };
  }

  /**
   * The salon answers.
   *
   * `confirm`, `complete` and `noShow` are three verbs rather than one
   * `setStatus`, because each has a different legal predecessor and a
   * different notification, and a generic setter would have let a salon mark a
   * cancelled appointment complete.
   */
  async confirm(user: AuthUser, id: string, dto: SalonNoteDto) {
    const appointment = await this.transition(user, id, {
      from: [AppointmentStatus.PENDING],
      to: AppointmentStatus.CONFIRMED,
      stamp: { confirmedAt: new Date() },
      note: dto.note,
    });
    await this.notify(appointment.customerId, {
      title: 'تم تأكيد موعدك',
      body: `${appointment.serviceName} — ${this.when(appointment.startsAt)}`,
      appointmentId: appointment.id,
    });
    return serializeAppointment(appointment);
  }

  async complete(user: AuthUser, id: string, dto: SalonNoteDto) {
    const appointment = await this.transition(user, id, {
      from: [AppointmentStatus.CONFIRMED, AppointmentStatus.PENDING],
      to: AppointmentStatus.COMPLETED,
      stamp: { completedAt: new Date() },
      note: dto.note,
    });
    await this.notify(appointment.customerId, {
      title: 'كيف كانت زيارتك؟',
      body: `قيّمي ${appointment.salon.name}`,
      appointmentId: appointment.id,
    });
    return serializeAppointment(appointment);
  }

  async noShow(user: AuthUser, id: string, dto: SalonNoteDto) {
    const appointment = await this.transition(user, id, {
      from: [AppointmentStatus.CONFIRMED, AppointmentStatus.PENDING],
      to: AppointmentStatus.NO_SHOW,
      stamp: {},
      note: dto.note,
    });
    return serializeAppointment(appointment);
  }

  // ── The sweeps ───────────────────────────────────────────────────────────

  /**
   * Reminders, once each.
   *
   * `reminderSentAt` is stamped in the same update that selects, so the
   * catch-up runs a sleeping Free instance performs on waking cannot send the
   * same reminder four times.
   */
  async sendDueReminders(now: Date = new Date()): Promise<number> {
    const lead =
      this.config.get<number>('salons.reminderLeadMinutes') ?? 720;
    const horizon = new Date(now.getTime() + lead * 60_000);

    const due = await this.prisma.appointment.findMany({
      where: {
        status: AppointmentStatus.CONFIRMED,
        reminderSentAt: null,
        startsAt: { gt: now, lte: horizon },
      },
      include: { salon: { select: { name: true } } },
      take: 200,
    });

    let sent = 0;
    for (const appointment of due) {
      // Stamped first. A notification that fails is better than one sent
      // twice, and the delivery table records the failure either way.
      const claimed = await this.prisma.appointment.updateMany({
        where: { id: appointment.id, reminderSentAt: null },
        data: { reminderSentAt: new Date() },
      });
      if (claimed.count === 0) continue;

      await this.notify(appointment.customerId, {
        title: 'تذكير بموعدك',
        body: `${appointment.salon.name} — ${this.when(appointment.startsAt)}`,
        appointmentId: appointment.id,
      });
      sent += 1;
    }
    return sent;
  }

  /**
   * Housekeeping the salon should not have to do by hand.
   *
   *  - A PENDING request whose time has passed is cancelled by the platform.
   *    Leaving it pending would hold a slot for ever and tell the customer
   *    nothing.
   *  - A CONFIRMED appointment a day past its end is taken as served, so the
   *    review can be written. The salon can still mark a no-show inside that
   *    day, which is why it is a day and not an hour.
   */
  async closeStaleAppointments(now: Date = new Date()): Promise<{
    expired: number;
    completed: number;
  }> {
    const autoCompleteAfter =
      this.config.get<number>('salons.autoCompleteAfterHours') ?? 24;

    const expired = await this.prisma.appointment.updateMany({
      where: { status: AppointmentStatus.PENDING, startsAt: { lt: now } },
      data: {
        status: AppointmentStatus.CANCELLED,
        cancelledAt: now,
        cancelledBy: AppointmentActor.SYSTEM,
        cancellationReason: 'لم يؤكّد الصالون الحجز قبل موعده',
      },
    });

    const completed = await this.prisma.appointment.updateMany({
      where: {
        status: AppointmentStatus.CONFIRMED,
        endsAt: { lt: new Date(now.getTime() - autoCompleteAfter * 3_600_000) },
      },
      data: { status: AppointmentStatus.COMPLETED, completedAt: now },
    });

    return { expired: expired.count, completed: completed.count };
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  private async transition(
    user: AuthUser,
    id: string,
    options: {
      from: AppointmentStatus[];
      to: AppointmentStatus;
      stamp: Prisma.AppointmentUpdateInput;
      note?: string;
    },
  ) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id },
      include: { salon: true },
    });
    if (!appointment) throw new NotFoundException('Appointment not found');
    if (appointment.salon.ownerId !== user.id) {
      throw new ForbiddenException('That is not your salon');
    }
    if (!options.from.includes(appointment.status)) {
      throw new ConflictException(
        `An appointment that is ${appointment.status} cannot become ${options.to}`,
      );
    }

    return this.prisma.appointment.update({
      where: { id },
      data: {
        ...options.stamp,
        status: options.to,
        ...(options.note === undefined
          ? {}
          : { salonNote: options.note.trim() || null }),
      },
      include: { ...SALON_CARD_INCLUDE, customer: true },
    });
  }

  private async assertOwner(user: AuthUser, salonId: string) {
    const salon = await this.prisma.salon.findUnique({
      where: { id: salonId },
      select: { ownerId: true },
    });
    if (!salon) throw new NotFoundException('Salon not found');
    if (salon.ownerId !== user.id) {
      throw new ForbiddenException('That is not your salon');
    }
  }

  private assertLocationAllowed(
    location: SalonServiceLocation,
    atHome: boolean,
    salonTravels: boolean,
  ) {
    if (atHome) {
      if (!salonTravels || location === SalonServiceLocation.IN_SALON) {
        throw new BadRequestException(
          'That service is not offered at home',
        );
      }
      return;
    }
    if (location === SalonServiceLocation.AT_HOME) {
      throw new BadRequestException('That service is only offered at home');
    }
  }

  private filterWhere(filter?: string): Prisma.AppointmentWhereInput {
    const now = new Date();
    switch (filter) {
      case 'upcoming':
        return {
          status: { in: LIVE_APPOINTMENT_STATUSES },
          startsAt: { gte: now },
        };
      case 'past':
        return {
          OR: [
            { startsAt: { lt: now } },
            {
              status: {
                in: [
                  AppointmentStatus.COMPLETED,
                  AppointmentStatus.CANCELLED,
                  AppointmentStatus.NO_SHOW,
                ],
              },
            },
          ],
        };
      case undefined:
      case '':
        return {};
      default:
        return { status: filter as AppointmentStatus };
    }
  }

  /** One local day, as the salon reckons it. */
  private dayWhere(date: string): Prisma.AppointmentWhereInput {
    const offset = this.availability.offsetMinutes;
    const from = new Date(
      new Date(`${date}T00:00:00.000Z`).getTime() - offset * 60_000,
    );
    const to = new Date(from.getTime() + 86_400_000);
    return { startsAt: { gte: from, lt: to } };
  }

  /** `RM-7K3Q9F` — short, unambiguous, and not a UUID. */
  private reference(): string {
    // No I, O, 0 or 1: this is read down a telephone.
    const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    const bytes = randomBytes(6);
    let out = '';
    for (const byte of bytes) out += alphabet[byte % alphabet.length];
    return `RM-${out}`;
  }

  /** «الخميس ١٨ أيلول، ٦:٠٠ م» — what a notification says. */
  private when(instant: Date): string {
    return new Intl.DateTimeFormat('ar-SY', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      hour: 'numeric',
      minute: '2-digit',
      timeZone: 'Asia/Damascus',
    }).format(instant);
  }

  private async refreshRating(tx: Prisma.TransactionClient, salonId: string) {
    const stats = await tx.salonReview.aggregate({
      where: { salonId, status: 'APPROVED' },
      _avg: { rating: true },
      _count: { _all: true },
    });
    await tx.salon.update({
      where: { id: salonId },
      data: {
        rating: Number((stats._avg.rating ?? 0).toFixed(2)),
        reviewsCount: stats._count._all,
      },
    });
  }

  /**
   * One notification, to one woman.
   *
   * Always TRANSACTIONAL: every message this feature sends is something she is
   * waiting for, and a reminder held back for quiet hours is a reminder that
   * arrives after the appointment. Failures are swallowed — a transport that
   * is down must not fail the booking it was reporting on.
   */
  private async notify(
    userId: string,
    message: { title: string; body: string; appointmentId: string },
  ) {
    try {
      await this.notifications.dispatch(userId, {
        user_ids: [userId],
        channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH],
        type: NotificationType.appointment,
        title: message.title,
        body: message.body,
        payload: { appointment_id: message.appointmentId },
        category: NotificationCategory.TRANSACTIONAL,
      });
    } catch (error) {
      this.logger.warn(
        `Appointment notification failed: ${(error as Error).message}`,
      );
    }
  }
}

