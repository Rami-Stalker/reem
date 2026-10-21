import assert from 'node:assert/strict';
import test from 'node:test';
import type { ConfigService } from '@nestjs/config';
import {
  AppointmentStatus,
  PrismaClient,
  SalonServiceLocation,
  SalonStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { NotificationsService } from '../notifications/notifications.service';
import { AppointmentsService } from './appointments.service';
import { SalonAvailabilityService } from './salon-availability.service';

/**
 * «الصالونات والجمال» against the real database.
 *
 * The unit specs prove the calendar arithmetic in isolation. This proves the
 * one thing that is only true when Postgres is involved: **a slot cannot be
 * sold twice.**
 *
 * That rule cannot be tested with a fake. It is a `FOR UPDATE` lock on the
 * salon row and an overlap count taken under it, and the failure mode it
 * exists to prevent — two transactions counting zero at the same instant and
 * both inserting — only appears when two real connections race. So the race is
 * run here, on purpose, with `Promise.all`.
 *
 * Unlike the other integration specs in this repo these cases commit and then
 * clean up after themselves rather than rolling back: two concurrent
 * transactions cannot both live inside a third, which is exactly what a
 * rollback harness would require. Every row created is deleted in a `finally`.
 */
const prisma = new PrismaClient();

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

test.after(() => prisma.$disconnect());

function dbTest(name: string, body: () => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    await body();
  });
}

// ── Harness ─────────────────────────────────────────────────────────────────

/** Silent: the transport is not what these cases are about. */
const notifications = {
  dispatch: async () => ({ queued: 0, recipients: 0, actor_id: '' }),
} as unknown as NotificationsService;

const config = {
  get: (key: string) =>
    key === 'salons.utcOffsetMinutes'
      ? 180
      : key === 'salons.reminderLeadMinutes'
        ? 720
        : key === 'salons.autoCompleteAfterHours'
          ? 24
          : undefined,
} as unknown as ConfigService;

function build() {
  const db = prisma as unknown as PrismaService;
  const availability = new SalonAvailabilityService(db, config);
  return {
    db,
    availability,
    appointments: new AppointmentsService(
      db,
      availability,
      notifications,
      config,
    ),
  };
}

const asUser = (id: string, role: UserRole = UserRole.CUSTOMER): AuthUser => ({
  id,
  phone: '+963900000000',
  role,
});

let sequence = 0;
function unique(prefix: string): string {
  sequence += 1;
  return `${prefix}-${Date.now().toString(36)}-${sequence}`;
}

/**
 * A salon open every day, one chair, with a one-hour service — and two
 * customers.
 *
 * Built rather than found: a fixture that searches the seed for something
 * suitable is a fixture that silently skips the moment the seed changes, and
 * the case this file exists for must never pass by not running.
 */
async function world(options: { capacity?: number } = {}) {
  const owner = await prisma.user.create({
    data: {
      name: 'صاحبة الصالون',
      username: unique('salon-owner'),
      phone: unique('+96390'),
      role: UserRole.SELLER,
    },
  });
  const [first, second] = await Promise.all([
    prisma.user.create({
      data: {
        name: 'ليلى',
        username: unique('customer-a'),
        phone: unique('+96391'),
      },
    }),
    prisma.user.create({
      data: {
        name: 'مريم',
        username: unique('customer-b'),
        phone: unique('+96392'),
      },
    }),
  ]);

  const salon = await prisma.salon.create({
    data: {
      ownerId: owner.id,
      name: 'صالون التجربة',
      slug: unique('salon'),
      status: SalonStatus.ACTIVE,
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'شارع الاختبار',
      slotMinutes: 60,
      // No lead time: the fixture books tomorrow, and a lead of two hours
      // would make the first slot of tomorrow morning unbookable at midnight.
      leadMinutes: 0,
      horizonDays: 30,
      concurrentCapacity: options.capacity ?? 1,
      cancellationHours: 4,
      hours: {
        create: Array.from({ length: 7 }, (_, weekday) => ({
          weekday,
          isClosed: false,
          opensAt: '09:00',
          closesAt: '21:00',
        })),
      },
    },
  });

  const service = await prisma.salonService.create({
    data: {
      salonId: salon.id,
      name: 'قص وتصفيف',
      category: 'HAIR',
      price: '150000',
      durationMinutes: 60,
      bufferMinutes: 0,
      location: SalonServiceLocation.IN_SALON,
    },
  });

  return {
    owner,
    first,
    second,
    salon,
    service,
    async cleanup() {
      await prisma.appointment.deleteMany({ where: { salonId: salon.id } });
      await prisma.salon.deleteMany({ where: { id: salon.id } });
      await prisma.user.deleteMany({
        where: { id: { in: [owner.id, first.id, second.id] } },
      });
    },
  };
}

/** Tomorrow at a whole local hour, as an instant. */
function tomorrowAt(hour: number): Date {
  const offsetMinutes = 180;
  const now = new Date();
  const local = new Date(now.getTime() + offsetMinutes * 60_000);
  const date = new Date(
    Date.UTC(
      local.getUTCFullYear(),
      local.getUTCMonth(),
      local.getUTCDate() + 1,
    ),
  );
  return new Date(date.getTime() + (hour * 60 - offsetMinutes) * 60_000);
}

// ── The invariant ───────────────────────────────────────────────────────────

/**
 * The race, at two capacities.
 *
 * Both are run because they probe different defences, and that was established
 * by deleting the `FOR UPDATE` and seeing which failed:
 *
 *  - **One chair.** Passes even without the lock. The availability pre-check
 *    saves it: once the first booking commits, every later racer's `slotsFor`
 *    sees the slot gone. Real defence in depth, and worth having — but not
 *    evidence that the lock works, so this case alone would be a test that
 *    cannot fail for the reason it claims to exist.
 *  - **Two chairs.** Fails without the lock, every time. Two bookings commit,
 *    and the third and fourth pre-checks still see capacity free (1 < 2), so
 *    both slip through and the salon ends up with three or four women in two
 *    chairs. This is the case that actually holds the lock accountable.
 *
 * Four racers rather than two for the same reason: each call does several
 * awaits before its transaction opens, so two calls can serialise by accident.
 *
 * The assertion is the invariant itself rather than a count of exceptions:
 * **never more live appointments than the salon has chairs.**
 */
for (const capacity of [1, 2]) {
  dbTest(
    `four women race for one slot at a salon with ${capacity} chair(s)`,
    async () => {
      const w = await world({ capacity });
      const { appointments } = build();
      const extra = await Promise.all(
        [0, 1].map((n) =>
          prisma.user.create({
            data: {
              name: `عميلة ${n}`,
              username: unique(`racer-${n}`),
              phone: unique('+96395'),
            },
          }),
        ),
      );
      const racers = [w.first, w.second, ...extra];

      try {
        const startsAt = tomorrowAt(14).toISOString();
        const results = await Promise.allSettled(
          racers.map((racer) =>
            appointments.book(asUser(racer.id), w.salon.id, {
              service_id: w.service.id,
              starts_at: startsAt,
            }),
          ),
        );

        const live = await prisma.appointment.count({
          where: {
            salonId: w.salon.id,
            status: {
              in: [AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED],
            },
          },
        });

        assert.equal(
          live,
          capacity,
          `${capacity} chair(s) must hold exactly ${capacity} women`,
        );
        assert.equal(
          results.filter((r) => r.status === 'fulfilled').length,
          capacity,
          'every caller that was told yes has a row, and no more',
        );
      } finally {
        await prisma.appointment.deleteMany({
          where: { customerId: { in: extra.map((u) => u.id) } },
        });
        await w.cleanup();
        await prisma.user.deleteMany({
          where: { id: { in: extra.map((u) => u.id) } },
        });
      }
    },
  );
}

dbTest('back-to-back bookings are two appointments, not a clash', async () => {
  // The half-open interval, end to end. A closed comparison here would halve
  // every salon's capacity and nobody would know why.
  const w = await world();
  const { appointments } = build();
  try {
    const first = await appointments.book(asUser(w.first.id), w.salon.id, {
      service_id: w.service.id,
      starts_at: tomorrowAt(16).toISOString(),
    });
    const second = await appointments.book(asUser(w.second.id), w.salon.id, {
      service_id: w.service.id,
      starts_at: tomorrowAt(17).toISOString(),
    });
    assert.ok(first.id !== second.id);
    assert.equal(first.ends_at, second.starts_at, 'one ends where the next begins');
  } finally {
    await w.cleanup();
  }
});

dbTest('a cancelled booking gives the slot back', async () => {
  const w = await world();
  const { appointments } = build();
  try {
    const startsAt = tomorrowAt(18).toISOString();
    const booked = await appointments.book(asUser(w.first.id), w.salon.id, {
      service_id: w.service.id,
      starts_at: startsAt,
    });

    await appointments.cancel(asUser(w.first.id), booked.id, {});

    // Somebody else can now have it — which is the whole reason CANCELLED is
    // not one of the statuses that occupies a chair.
    const retaken = await appointments.book(asUser(w.second.id), w.salon.id, {
      service_id: w.service.id,
      starts_at: startsAt,
    });
    assert.equal(retaken.status, 'PENDING');
  } finally {
    await w.cleanup();
  }
});

dbTest('a taken slot stops being offered', async () => {
  const w = await world();
  const { appointments, availability } = build();
  try {
    const when = tomorrowAt(11);
    const date = availability.localDate(when);

    const before = await availability.slotsFor(w.salon.id, w.service.id, date);
    assert.ok(
      before.some((slot) => slot.startsAt.getTime() === when.getTime()),
      'eleven should be free to begin with',
    );

    await appointments.book(asUser(w.first.id), w.salon.id, {
      service_id: w.service.id,
      starts_at: when.toISOString(),
    });

    const after = await availability.slotsFor(w.salon.id, w.service.id, date);
    assert.ok(
      !after.some((slot) => slot.startsAt.getTime() === when.getTime()),
      'the day view and the booking rule must agree',
    );
    assert.equal(after.length, before.length - 1);
  } finally {
    await w.cleanup();
  }
});

dbTest('a closed day offers nothing', async () => {
  const w = await world();
  const { availability } = build();
  try {
    const when = tomorrowAt(12);
    const date = availability.localDate(when);
    const weekday = new Date(`${date}T00:00:00.000Z`).getUTCDay();

    await prisma.salonWorkingHours.update({
      where: { salonId_weekday: { salonId: w.salon.id, weekday } },
      data: { isClosed: true },
    });

    assert.deepEqual(
      await availability.slotsFor(w.salon.id, w.service.id, date),
      [],
    );
  } finally {
    await w.cleanup();
  }
});

dbTest('a closure shuts one date and leaves the rest open', async () => {
  const w = await world();
  const { availability } = build();
  try {
    const when = tomorrowAt(12);
    const date = availability.localDate(when);

    await prisma.salonClosure.create({
      data: {
        salonId: w.salon.id,
        date: new Date(`${date}T00:00:00.000Z`),
        reason: 'عيد',
      },
    });

    assert.deepEqual(
      await availability.slotsFor(w.salon.id, w.service.id, date),
      [],
    );

    const dayAfter = availability.localDate(
      new Date(when.getTime() + 86_400_000),
    );
    assert.ok(
      (await availability.slotsFor(w.salon.id, w.service.id, dayAfter)).length >
        0,
      'a feast day is one day',
    );
  } finally {
    await w.cleanup();
  }
});

// ── The lifecycle ───────────────────────────────────────────────────────────

dbTest('only a completed appointment can be reviewed', async () => {
  const w = await world();
  const { appointments } = build();
  try {
    const booked = await appointments.book(asUser(w.first.id), w.salon.id, {
      service_id: w.service.id,
      starts_at: tomorrowAt(10).toISOString(),
    });

    await assert.rejects(
      () => appointments.review(asUser(w.first.id), booked.id, { rating: 5 }),
      /completed/i,
      'a rating before the visit is not a rating of anything',
    );

    await appointments.confirm(asUser(w.owner.id, UserRole.SELLER), booked.id, {});
    await appointments.complete(asUser(w.owner.id, UserRole.SELLER), booked.id, {});

    const review = await appointments.review(asUser(w.first.id), booked.id, {
      rating: 5,
      body: 'ممتاز',
    });
    assert.equal(review.rating, 5);
    assert.equal(review.verified, true);

    // And the salon's roll-up moved, because a directory ranks on it.
    const salon = await prisma.salon.findUnique({ where: { id: w.salon.id } });
    assert.equal(salon?.rating, 5);
    assert.equal(salon?.reviewsCount, 1);

    await assert.rejects(
      () => appointments.review(asUser(w.first.id), booked.id, { rating: 1 }),
      /already/i,
      'one review per appointment',
    );
  } finally {
    await prisma.salonReview.deleteMany({ where: { salonId: w.salon.id } });
    await w.cleanup();
  }
});

dbTest('a salon cannot confirm an appointment that is already cancelled', async () => {
  const w = await world();
  const { appointments } = build();
  try {
    const booked = await appointments.book(asUser(w.first.id), w.salon.id, {
      service_id: w.service.id,
      starts_at: tomorrowAt(19).toISOString(),
    });
    await appointments.cancel(asUser(w.first.id), booked.id, { reason: 'ظرف' });

    await assert.rejects(
      () =>
        appointments.confirm(asUser(w.owner.id, UserRole.SELLER), booked.id, {}),
      /cannot become/i,
    );
  } finally {
    await w.cleanup();
  }
});

dbTest('a stranger can neither read nor cancel somebody else’s appointment', async () => {
  const w = await world();
  const { appointments } = build();
  const stranger = await prisma.user.create({
    data: { name: 'غريبة', username: unique('stranger'), phone: unique('+96394') },
  });
  try {
    const booked = await appointments.book(asUser(w.first.id), w.salon.id, {
      service_id: w.service.id,
      starts_at: tomorrowAt(20).toISOString(),
    });

    await assert.rejects(
      () => appointments.detail(asUser(stranger.id), booked.id),
      /not your appointment/i,
    );
    await assert.rejects(
      () => appointments.cancel(asUser(stranger.id), booked.id, {}),
      /not your appointment/i,
    );
  } finally {
    await w.cleanup();
    await prisma.user.deleteMany({ where: { id: stranger.id } });
  }
});

dbTest('the salon sees the customer on its queue; she does not see herself on hers', async () => {
  const w = await world();
  const { appointments } = build();
  try {
    const booked = await appointments.book(asUser(w.first.id), w.salon.id, {
      service_id: w.service.id,
      starts_at: tomorrowAt(13).toISOString(),
    });

    const salonView = await appointments.detail(
      asUser(w.owner.id, UserRole.SELLER),
      booked.id,
    );
    assert.ok(salonView.customer, 'the salon needs to know who is coming');

    const herView = await appointments.detail(asUser(w.first.id), booked.id);
    assert.equal(
      herView.customer,
      null,
      'her own contact details do not belong in a payload she can forward',
    );
  } finally {
    await w.cleanup();
  }
});

// ── The sweeps ──────────────────────────────────────────────────────────────

dbTest('a request nobody answered stops holding the slot once its time passes', async () => {
  const w = await world();
  const { appointments } = build();
  try {
    const booked = await appointments.book(asUser(w.first.id), w.salon.id, {
      service_id: w.service.id,
      starts_at: tomorrowAt(9).toISOString(),
    });

    // The sweep is asked to reckon from a moment after the appointment rather
    // than the row being back-dated, so the predicate under test is the real
    // one.
    const after = new Date(Date.now() + 3 * 86_400_000);
    const { expired } = await appointments.closeStaleAppointments(after);
    assert.ok(expired >= 1);

    const row = await prisma.appointment.findUnique({ where: { id: booked.id } });
    assert.equal(row?.status, AppointmentStatus.CANCELLED);
    assert.equal(row?.cancelledBy, 'SYSTEM');
  } finally {
    await w.cleanup();
  }
});

dbTest('a reminder is sent once, however many times the sweep runs', async () => {
  // The Free instance wakes and runs every overdue job in a catch-up pass, so
  // "once" has to be a property of the row and not of the schedule.
  const w = await world();
  const { appointments } = build();
  try {
    const booked = await appointments.book(asUser(w.first.id), w.salon.id, {
      service_id: w.service.id,
      starts_at: tomorrowAt(12).toISOString(),
    });
    await appointments.confirm(
      asUser(w.owner.id, UserRole.SELLER),
      booked.id,
      {},
    );

    // Reckoned from just inside the twelve-hour lead.
    const justBefore = new Date(
      new Date(booked.starts_at).getTime() - 60 * 60_000,
    );
    const first = await appointments.sendDueReminders(justBefore);
    const second = await appointments.sendDueReminders(justBefore);

    assert.equal(first, 1);
    assert.equal(second, 0, 'the second pass must find nothing');

    const row = await prisma.appointment.findUnique({ where: { id: booked.id } });
    assert.ok(row?.reminderSentAt);
  } finally {
    await w.cleanup();
  }
});
