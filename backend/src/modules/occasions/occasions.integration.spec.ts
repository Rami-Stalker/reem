import assert from 'node:assert/strict';
import test from 'node:test';
import type { ConfigService } from '@nestjs/config';
import {
  AppointmentStatus,
  ClosetItemSource,
  OccasionKind,
  OutfitSlot,
  PrismaClient,
  SalonServiceLocation,
  SalonStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { addDays, localDate } from './occasion-plan';
import { OccasionsService } from './occasions.service';
import { serializeOccasion } from './occasions.serializer';

/**
 * «مناسباتي» against the real database.
 *
 * `occasion-plan.spec.ts` proves the arithmetic. This proves what only holds
 * with Postgres involved: that the two links are checked to be hers, that a
 * deleted look leaves the wedding standing, that the plan reads the
 * appointment's live status, and that the countdown claims each mark once
 * however many sweeps run.
 *
 * Every row is created here and deleted in a `finally`, so the case never
 * depends on — or disturbs — the demo seed.
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

const OFFSET = 180;

function build() {
  const sent: { userId: string; title: string; occasionId: unknown }[] = [];
  const notifications = {
    dispatch: async (
      _actor: string,
      message: { user_ids: string[]; title: string; payload: Record<string, unknown> },
    ) => {
      for (const userId of message.user_ids) {
        sent.push({ userId, title: message.title, occasionId: message.payload.occasion_id });
      }
      return { queued: 1, recipients: 1, actor_id: '' };
    },
  } as unknown as NotificationsService;
  const config = {
    get: (key: string) => (key === 'salons.utcOffsetMinutes' ? OFFSET : undefined),
  } as unknown as ConfigService;
  return {
    sent,
    service: new OccasionsService(prisma as unknown as PrismaService, notifications, config),
  };
}

let sequence = 0;
function unique(prefix: string): string {
  sequence += 1;
  return `${prefix}-${Date.now().toString(36)}-${sequence}`;
}

/** Noon today in Damascus — inside the sending hours whatever the CI clock. */
function noonToday(): Date {
  const today = localDate(new Date(), OFFSET);
  return new Date(Date.parse(`${today}T12:00:00.000Z`) - OFFSET * 60_000);
}

const today = () => localDate(new Date(), OFFSET);

/**
 * Two women, a closet and a look for the first, and a salon booking each.
 *
 * Built rather than found, so the case cannot pass by skipping when the seed
 * changes.
 */
async function world() {
  const [her, other, owner] = await Promise.all(
    ['ليلى', 'مريم', 'صاحبة الصالون'].map((name, index) =>
      prisma.user.create({
        data: {
          name,
          username: unique(`occasion-user-${index}`),
          phone: unique('+96393'),
          role: index === 2 ? UserRole.SELLER : UserRole.CUSTOMER,
        },
      }),
    ),
  );

  const closet = await prisma.closet.create({ data: { userId: her.id } });
  const [dress, shoes] = await Promise.all([
    prisma.closetItem.create({
      data: {
        closetId: closet.id,
        userId: her.id,
        source: ClosetItemSource.PERSONAL,
        title: 'فستان زيتي',
        slot: OutfitSlot.DRESS,
      },
    }),
    prisma.closetItem.create({
      data: {
        closetId: closet.id,
        userId: her.id,
        source: ClosetItemSource.PERSONAL,
        title: 'كعب ذهبي',
        slot: OutfitSlot.SHOES,
      },
    }),
  ]);
  const look = await prisma.closetLook.create({
    data: {
      closetId: closet.id,
      userId: her.id,
      title: 'إطلالة السهرة',
      isComplete: true,
      items: {
        create: [
          { slot: OutfitSlot.DRESS, closetItemId: dress.id, position: 0 },
          { slot: OutfitSlot.SHOES, closetItemId: shoes.id, position: 1 },
        ],
      },
    },
  });

  const salon = await prisma.salon.create({
    data: {
      ownerId: owner.id,
      name: 'صالون المناسبات',
      slug: unique('occasion-salon'),
      status: SalonStatus.ACTIVE,
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'شارع الاختبار',
    },
  });
  const service = await prisma.salonService.create({
    data: {
      salonId: salon.id,
      name: 'تسريحة',
      category: 'HAIR',
      price: '150000',
      durationMinutes: 60,
      location: SalonServiceLocation.IN_SALON,
    },
  });
  const book = (customerId: string) =>
    prisma.appointment.create({
      data: {
        reference: unique('RM').slice(0, 16),
        salonId: salon.id,
        customerId,
        serviceId: service.id,
        status: AppointmentStatus.PENDING,
        startsAt: new Date(Date.now() + 3 * 86_400_000),
        endsAt: new Date(Date.now() + 3 * 86_400_000 + 3_600_000),
        serviceName: service.name,
        durationMinutes: 60,
        price: '150000',
      },
    });
  const [herBooking, otherBooking] = await Promise.all([book(her.id), book(other.id)]);

  return {
    her,
    other,
    look,
    dress,
    herBooking,
    otherBooking,
    async cleanup() {
      await prisma.occasion.deleteMany({ where: { userId: { in: [her.id, other.id] } } });
      await prisma.appointment.deleteMany({ where: { salonId: salon.id } });
      await prisma.salonService.deleteMany({ where: { salonId: salon.id } });
      await prisma.salon.deleteMany({ where: { id: salon.id } });
      await prisma.user.deleteMany({ where: { id: { in: [her.id, other.id, owner.id] } } });
    },
  };
}

// ── Cases ───────────────────────────────────────────────────────────────────

dbTest('the look and the appointment must be hers', async () => {
  const w = await world();
  const { service } = build();
  try {
    // Her own look and booking link fine.
    const occasion = await service.create(w.her.id, {
      title: 'عرس سارة',
      kind: OccasionKind.WEDDING,
      date: addDays(today(), 10),
      lookId: w.look.id,
      appointmentId: w.herBooking.id,
    });
    assert.equal(occasion.lookId, w.look.id);
    assert.equal(occasion.appointmentId, w.herBooking.id);

    // Somebody else's booking at the same salon does not.
    await assert.rejects(
      service.update(w.her.id, occasion.id, { appointmentId: w.otherBooking.id }),
      /not yours/,
    );
    // Nor may another woman point her occasion at this look.
    await assert.rejects(
      service.create(w.other.id, {
        title: 'سهرة',
        kind: OccasionKind.EVENING,
        date: addDays(today(), 3),
        lookId: w.look.id,
      }),
      /not in your closet/,
    );
    // Nor read the occasion itself.
    await assert.rejects(service.require(w.other.id, occasion.id), /not found/);
  } finally {
    await w.cleanup();
  }
});

dbTest('the plan reads the appointment live, and a deleted look leaves the day standing', async () => {
  const w = await world();
  const { service } = build();
  try {
    const created = await service.create(w.her.id, {
      title: 'خطوبة لينا',
      kind: OccasionKind.ENGAGEMENT,
      date: addDays(today(), 4),
      lookId: w.look.id,
      appointmentId: w.herBooking.id,
    });
    const stepState = async (key: string) => {
      const row = await service.require(w.her.id, created.id);
      return serializeOccasion(row, { today: today() }).steps.find((step) => step.key === key)
        ?.state;
    };

    assert.equal(await stepState('look'), 'DONE');
    assert.equal(await stepState('salon'), 'WAITING');

    await prisma.appointment.update({
      where: { id: w.herBooking.id },
      data: { status: AppointmentStatus.CONFIRMED },
    });
    assert.equal(await stepState('salon'), 'DONE');

    // The salon cancels: nothing on the occasion was told, and the step is
    // to-do again anyway.
    await prisma.appointment.update({
      where: { id: w.herBooking.id },
      data: { status: AppointmentStatus.CANCELLED },
    });
    assert.equal(await stepState('salon'), 'TODO');

    // The gift is ticked by hand, and only the gift.
    await service.setStep(w.her.id, created.id, 'gift', true);
    assert.equal(await stepState('gift'), 'DONE');
    await assert.rejects(service.setStep(w.her.id, created.id, 'salon', true), /by hand/);

    await prisma.closetLook.delete({ where: { id: w.look.id } });
    const after = await service.require(w.her.id, created.id);
    assert.equal(after.lookId, null);
    assert.equal(await stepState('look'), 'TODO');
  } finally {
    await w.cleanup();
  }
});

dbTest('the countdown rings once per mark, however many sweeps run', async () => {
  const w = await world();
  const { service, sent } = build();
  try {
    const now = noonToday();
    // Written down for ten days out: no stage yet.
    const occasion = await service.create(w.her.id, {
      title: 'عرس سارة',
      kind: OccasionKind.WEDDING,
      date: addDays(today(), 10),
    });
    // And one written down for two days out, which must *not* ring at once.
    await service.create(w.her.id, {
      title: 'حنّة سلمى',
      kind: OccasionKind.HENNA,
      date: addDays(today(), 2),
    });

    await service.sendDueReminders(now);
    assert.equal(sent.filter((row) => row.userId === w.her.id).length, 0);

    // A week to go.
    await prisma.occasion.update({
      where: { id: occasion.id },
      data: { date: new Date(`${addDays(today(), 7)}T00:00:00.000Z`) },
    });
    await Promise.all([service.sendDueReminders(now), service.sendDueReminders(now)]);
    await service.sendDueReminders(now);

    const mine = sent.filter((row) => row.userId === w.her.id);
    assert.equal(mine.length, 1, 'concurrent and repeated sweeps ring once');
    assert.equal(mine[0].occasionId, occasion.id);
    assert.equal(mine[0].title, '«عرس سارة» بعد ٧ أيام');

    // At three in the morning nothing rings, and the mark stays unclaimed.
    await prisma.occasion.update({
      where: { id: occasion.id },
      data: { date: new Date(`${addDays(today(), 3)}T00:00:00.000Z`) },
    });
    const night = new Date(now.getTime() - 9 * 3_600_000);
    assert.equal(await service.sendDueReminders(night), 0);
    await service.sendDueReminders(now);
    assert.equal(sent.filter((row) => row.userId === w.her.id).length, 2);

    // Switched off, it stays quiet.
    await service.update(w.her.id, occasion.id, { remindersEnabled: false });
    await prisma.occasion.update({
      where: { id: occasion.id },
      data: { date: new Date(`${addDays(today(), 1)}T00:00:00.000Z`) },
    });
    await service.sendDueReminders(now);
    assert.equal(sent.filter((row) => row.userId === w.her.id).length, 2);
  } finally {
    await w.cleanup();
  }
});

dbTest('the same dress in front of the same people is caught across occasions', async () => {
  const w = await world();
  const { service } = build();
  try {
    await service.create(w.her.id, {
      title: 'خطوبة لينا',
      kind: OccasionKind.ENGAGEMENT,
      date: addDays(today(), -60),
      circle: 'أهل زوجي',
      lookId: w.look.id,
    });
    const wedding = await service.create(w.her.id, {
      title: 'عرس سارة',
      kind: OccasionKind.WEDDING,
      date: addDays(today(), 20),
      // Spelled without the hamza this time.
      circle: 'اهل زوجي',
      lookId: w.look.id,
    });
    const repeats = await service.repeatsFor(wedding);
    assert.equal(repeats.length, 1);
    assert.equal(repeats[0].title, 'خطوبة لينا');
    assert.equal(repeats[0].sameLook, true);
    assert.equal(repeats[0].upcoming, false);
    assert.deepEqual(repeats[0].pieces.map((piece) => piece.id), [w.dress.id]);

    // Different people: no warning.
    await service.update(w.her.id, wedding.id, { circle: 'زميلات الشغل' });
    assert.deepEqual(await service.repeatsFor(await service.require(w.her.id, wedding.id)), []);
  } finally {
    await w.cleanup();
  }
});

dbTest('upcoming and past are split on her local today', async () => {
  const w = await world();
  const { service } = build();
  try {
    for (const [title, offset] of [
      ['اليوم', 0],
      ['بعد أسبوع', 7],
      ['البارحة', -1],
    ] as const) {
      await service.create(w.her.id, {
        title,
        kind: OccasionKind.OTHER,
        date: addDays(today(), offset),
      });
    }
    const upcoming = await service.list(w.her.id, 'upcoming');
    const past = await service.list(w.her.id, 'past');
    assert.deepEqual(upcoming.map((row) => row.title), ['اليوم', 'بعد أسبوع']);
    assert.deepEqual(past.map((row) => row.title), ['البارحة']);

    await assert.rejects(
      service.create(w.her.id, { title: 'خطأ', kind: OccasionKind.OTHER, date: '2026-02-31' }),
      /Invalid date/,
    );
    await assert.rejects(
      service.create(w.her.id, { title: 'خطأ', kind: OccasionKind.OTHER, date: '2099-01-01' }),
      /out of range/,
    );
  } finally {
    await w.cleanup();
  }
});
