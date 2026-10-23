import assert from 'node:assert/strict';
import test from 'node:test';
import { AppointmentStatus, OccasionKind, OutfitSlot } from '@prisma/client';
import {
  OccasionOutfit,
  addDays,
  circleKeyOf,
  daysBetween,
  dueStage,
  findRepeats,
  localDate,
  nextStep,
  planSteps,
  progressOf,
  reminderCopy,
  shouldRemind,
  whenPhrase,
  withinSendingHours,
} from './occasion-plan';

/**
 * «مناسباتي», as arithmetic — walked through without a database or a clock.
 */

const DAMASCUS = 180;

// ── The calendar ────────────────────────────────────────────────────────────

test('the local day turns at midnight in Damascus, not in UTC', () => {
  // 21:30 UTC is 00:30 the next day in Damascus.
  assert.equal(localDate(new Date('2026-10-23T21:30:00Z'), DAMASCUS), '2026-10-24');
  assert.equal(localDate(new Date('2026-10-23T20:59:00Z'), DAMASCUS), '2026-10-23');
});

test('days between two calendar days, either direction', () => {
  assert.equal(daysBetween('2026-10-23', '2026-10-30'), 7);
  assert.equal(daysBetween('2026-10-23', '2026-10-23'), 0);
  assert.equal(daysBetween('2026-10-23', '2026-10-20'), -3);
  // Across a month end and a year end.
  assert.equal(daysBetween('2026-12-30', '2027-01-02'), 3);
  assert.equal(addDays('2026-12-30', 3), '2027-01-02');
});

// ── The countdown ───────────────────────────────────────────────────────────

test('the stage a day falls in', () => {
  assert.equal(dueStage(10), null, 'beyond the first mark');
  assert.equal(dueStage(7), 7);
  assert.equal(dueStage(5), 7);
  assert.equal(dueStage(3), 3);
  assert.equal(dueStage(2), 3);
  assert.equal(dueStage(1), 1);
  assert.equal(dueStage(0), 1);
  assert.equal(dueStage(-1), null, 'a past day has no countdown');
});

test('a wedding written down three weeks ahead rings at 7, 3 and 1 — once each', () => {
  let last = dueStage(21); // what create stores
  assert.equal(last, null);

  const rang: number[] = [];
  for (let daysLeft = 21; daysLeft >= -1; daysLeft -= 1) {
    // Two sweeps a day, as a catch-up pass plus the hourly tick would make.
    for (let pass = 0; pass < 2; pass += 1) {
      const stage = shouldRemind(daysLeft, last);
      if (stage !== null) {
        rang.push(daysLeft);
        last = stage;
      }
    }
  }
  assert.deepEqual(rang, [7, 3, 1]);
});

test('a day written down five days ahead waits for the three-day mark', () => {
  // She knows it is in five days; she just typed it.
  let last = dueStage(5);
  assert.equal(shouldRemind(5, last), null);
  assert.equal(shouldRemind(4, last), null);
  const stage = shouldRemind(3, last);
  assert.equal(stage, 3);
  last = stage;
  assert.equal(shouldRemind(2, last), null);
  assert.equal(shouldRemind(1, last), 1);
});

test('a day written down for tomorrow does not ring at all', () => {
  const last = dueStage(1);
  assert.equal(shouldRemind(1, last), null);
  assert.equal(shouldRemind(0, last), null);
});

test('a missed mark still rings once on the next pass, with the true count', () => {
  // The instance slept through the whole of the three-day mark's day.
  const last = 7;
  assert.equal(shouldRemind(2, last), 3);
  assert.equal(whenPhrase(2), 'بعد يومين');
});

test('the countdown only rings in the daytime, local', () => {
  // 06:00 UTC = 09:00 Damascus: too early.
  assert.equal(withinSendingHours(new Date('2026-10-23T06:00:00Z'), DAMASCUS), false);
  // 07:00 UTC = 10:00 Damascus.
  assert.equal(withinSendingHours(new Date('2026-10-23T07:00:00Z'), DAMASCUS), true);
  // 17:59 UTC = 20:59 Damascus.
  assert.equal(withinSendingHours(new Date('2026-10-23T17:59:00Z'), DAMASCUS), true);
  // 18:00 UTC = 21:00 Damascus: too late.
  assert.equal(withinSendingHours(new Date('2026-10-23T18:00:00Z'), DAMASCUS), false);
  // 00:00 UTC = 03:00 Damascus.
  assert.equal(withinSendingHours(new Date('2026-10-24T00:00:00Z'), DAMASCUS), false);
});

test('the words for "when", in Arabic', () => {
  assert.equal(whenPhrase(0), 'اليوم');
  assert.equal(whenPhrase(1), 'غداً');
  assert.equal(whenPhrase(3), 'بعد ٣ أيام');
  assert.equal(whenPhrase(7), 'بعد ٧ أيام');
  assert.equal(whenPhrase(11), 'بعد ١١ يوماً');
});

// ── The plan ────────────────────────────────────────────────────────────────

test('a wedding with nothing done: look, salon, gift — in that order', () => {
  const steps = planSteps({
    kind: OccasionKind.WEDDING,
    daysLeft: 14,
    look: null,
    appointment: null,
    doneSteps: [],
  });
  assert.deepEqual(steps.map((step) => step.key), ['look', 'salon', 'gift']);
  assert.ok(steps.every((step) => step.state === 'TODO'));
  assert.ok(steps.every((step) => !step.urgent), 'two weeks out, nothing is urgent');
  assert.equal(nextStep(steps)?.key, 'look');
  assert.deepEqual(progressOf(steps), { done: 0, total: 3 });
});

test('a work dinner asks for a look and nothing else', () => {
  const steps = planSteps({
    kind: OccasionKind.WORK,
    daysLeft: 3,
    look: null,
    appointment: null,
    doneSteps: [],
  });
  assert.deepEqual(steps.map((step) => step.key), ['look']);
});

test('a look missing pieces adds the pieces step, urgent inside five days', () => {
  const steps = planSteps({
    kind: OccasionKind.WEDDING,
    daysLeft: 5,
    look: { missingCount: 2 },
    appointment: null,
    doneSteps: [],
  });
  const pieces = steps.find((step) => step.key === 'pieces');
  assert.ok(pieces);
  assert.equal(pieces.count, 2);
  assert.equal(pieces.urgent, true, 'a courier needs days');
  assert.equal(steps.find((step) => step.key === 'salon')?.urgent, false, 'not yet');
  assert.equal(nextStep(steps)?.key, 'pieces');
});

test('a complete look adds no pieces step at all', () => {
  const steps = planSteps({
    kind: OccasionKind.EVENING,
    daysLeft: 5,
    look: { missingCount: 0 },
    appointment: null,
    doneSteps: [],
  });
  assert.deepEqual(steps.map((step) => step.key), ['look', 'salon']);
  assert.equal(steps[0].state, 'DONE');
});

test('the salon step follows the appointment, including when the salon cancels', () => {
  const salon = (status: AppointmentStatus | null) =>
    planSteps({
      kind: OccasionKind.ENGAGEMENT,
      daysLeft: 2,
      look: { missingCount: 0 },
      appointment: status ? { status } : null,
      doneSteps: [],
    }).find((step) => step.key === 'salon')!;

  assert.equal(salon(AppointmentStatus.PENDING).state, 'WAITING');
  assert.equal(salon(AppointmentStatus.PENDING).urgent, false, 'she has acted');
  assert.equal(salon(AppointmentStatus.CONFIRMED).state, 'DONE');
  assert.equal(salon(AppointmentStatus.COMPLETED).state, 'DONE');
  // The case a stored flag would get wrong.
  assert.equal(salon(AppointmentStatus.CANCELLED).state, 'TODO');
  assert.equal(salon(AppointmentStatus.CANCELLED).urgent, true);
  assert.equal(salon(AppointmentStatus.NO_SHOW).state, 'TODO');
});

test('the gift is the one step she ticks by hand', () => {
  const steps = planSteps({
    kind: OccasionKind.BIRTHDAY,
    daysLeft: 1,
    look: { missingCount: 0 },
    appointment: null,
    doneSteps: ['gift'],
  });
  const gift = steps.find((step) => step.key === 'gift')!;
  assert.equal(gift.manual, true);
  assert.equal(gift.state, 'DONE');
  assert.equal(nextStep(steps), null, 'she is ready');
  assert.deepEqual(progressOf(steps), { done: 2, total: 2 });
});

test('a past occasion has no plan', () => {
  assert.deepEqual(
    planSteps({
      kind: OccasionKind.WEDDING,
      daysLeft: -1,
      look: null,
      appointment: null,
      doneSteps: [],
    }),
    [],
  );
});

test('the reminder says when, and the one thing to do next', () => {
  const steps = planSteps({
    kind: OccasionKind.WEDDING,
    daysLeft: 3,
    look: { missingCount: 0 },
    appointment: null,
    doneSteps: [],
  });
  const copy = reminderCopy('عرس سارة', 3, nextStep(steps));
  assert.equal(copy.title, '«عرس سارة» بعد ٣ أيام');
  assert.match(copy.body, /الصالون/);

  const ready = reminderCopy('عرس سارة', 1, null);
  assert.equal(ready.title, '«عرس سارة» غداً');
  assert.match(ready.body, /جاهز/);
});

// ── «ما لبستيه قدّامهم» ──────────────────────────────────────────────────────

test('the circle is matched however she spells it', () => {
  assert.equal(circleKeyOf('أهل زوجي'), circleKeyOf('اهل زوجي'));
  assert.equal(circleKeyOf('بنات الجامعة'), circleKeyOf('بنات الجامعه'));
  assert.equal(circleKeyOf('   '), null);
  assert.equal(circleKeyOf(null), null);
});

const dress = { id: 'dress-1', title: 'فستان زيتي', slot: OutfitSlot.DRESS };
const shoes = { id: 'shoes-1', title: 'كعب ذهبي', slot: OutfitSlot.SHOES };
const abaya = { id: 'abaya-1', title: 'عباية سوداء', slot: OutfitSlot.ABAYA };

function outfit(overrides: Partial<OccasionOutfit>): OccasionOutfit {
  return {
    id: 'target',
    title: 'عرس ريم',
    date: '2026-11-20',
    lookId: 'look-a',
    circleKey: circleKeyOf('أهل زوجي'),
    pieces: [dress, shoes],
    ...overrides,
  };
}

test('the same dress in front of the same people is caught', () => {
  const warnings = findRepeats(
    outfit({}),
    [
      outfit({
        id: 'june',
        title: 'خطوبة لينا',
        date: '2026-06-12',
        lookId: 'look-b',
        pieces: [dress],
      }),
    ],
    '2026-10-23',
  );
  assert.equal(warnings.length, 1);
  assert.equal(warnings[0].occasionId, 'june');
  assert.equal(warnings[0].sameLook, false);
  assert.equal(warnings[0].upcoming, false);
  assert.deepEqual(warnings[0].pieces.map((piece) => piece.id), ['dress-1']);
});

test('the same look is caught, and planned-for occasions count too', () => {
  const warnings = findRepeats(
    outfit({}),
    [outfit({ id: 'soon', title: 'حنّة سلمى', date: '2026-11-12', pieces: [] })],
    '2026-10-23',
  );
  assert.equal(warnings.length, 1);
  assert.equal(warnings[0].sameLook, true);
  assert.equal(warnings[0].upcoming, true);
});

test('shoes repeating is not a warning', () => {
  const warnings = findRepeats(
    outfit({}),
    [outfit({ id: 'june', lookId: 'look-b', pieces: [shoes, abaya] })],
    '2026-10-23',
  );
  assert.deepEqual(warnings, []);
});

test('different people, or no people named, is never a warning', () => {
  const others = [
    outfit({ id: 'work', circleKey: circleKeyOf('زميلات الشغل'), pieces: [dress] }),
    outfit({ id: 'unnamed', circleKey: null, pieces: [dress] }),
  ];
  assert.deepEqual(findRepeats(outfit({}), others, '2026-10-23'), []);
  assert.deepEqual(
    findRepeats(outfit({ circleKey: null }), [outfit({ id: 'x', circleKey: null })], '2026-10-23'),
    [],
  );
});

test('the nearest repeat comes first', () => {
  const warnings = findRepeats(
    outfit({}),
    [
      outfit({ id: 'far', date: '2025-12-01', lookId: 'look-x', pieces: [dress] }),
      outfit({ id: 'near', date: '2026-10-01', lookId: 'look-y', pieces: [dress] }),
    ],
    '2026-10-23',
  );
  assert.deepEqual(warnings.map((warning) => warning.occasionId), ['near', 'far']);
});
