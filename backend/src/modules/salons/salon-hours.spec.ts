import assert from 'node:assert/strict';
import test from 'node:test';
import {
  candidateStarts,
  instantAt,
  localDateOf,
  minutesOfDay,
  openWindows,
  overlaps,
  parseLocalDate,
  timeOfDay,
  weekdayOf,
} from './salon-hours';

/**
 * The clock on the wall.
 *
 * Every one of these is a rule a salon owner can break by typing, or a
 * timezone mistake that would look like bad data rather than like a bug: a
 * whole directory's opening hours shifted by a day, or by three.
 */

// ── Parsing ─────────────────────────────────────────────────────────────────

test('a time of day is HH:mm, and nothing else is', () => {
  assert.equal(minutesOfDay('09:30'), 570);
  assert.equal(minutesOfDay('00:00'), 0);
  assert.equal(minutesOfDay('23:59'), 1439);
  // Everything a salon might actually type, refused rather than guessed at.
  assert.equal(minutesOfDay('9:30'), null);
  assert.equal(minutesOfDay('24:00'), null);
  assert.equal(minutesOfDay('09:60'), null);
  assert.equal(minutesOfDay('nine'), null);
  assert.equal(minutesOfDay(''), null);
  assert.equal(minutesOfDay(null), null);
});

test('a time of day round-trips', () => {
  for (const value of ['00:00', '09:30', '13:05', '23:59']) {
    assert.equal(timeOfDay(minutesOfDay(value)!), value);
  }
});

test('a date that does not exist is refused, not rolled forward', () => {
  assert.deepEqual(parseLocalDate('2026-09-17'), {
    year: 2026,
    month: 9,
    day: 17,
  });
  // The one that matters: `new Date(2026, 1, 31)` is the 3rd of March, and a
  // calendar that silently books her on a different day than she tapped is
  // worse than one that refuses.
  assert.equal(parseLocalDate('2026-02-31'), null);
  assert.equal(parseLocalDate('2026-13-01'), null);
  assert.equal(parseLocalDate('17-09-2026'), null);
  assert.equal(parseLocalDate(''), null);
});

// ── Timezone ────────────────────────────────────────────────────────────────

test('nine in the morning is nine in the morning, whatever the server thinks', () => {
  const date = parseLocalDate('2026-09-17')!;
  // +03:00. Nine local is six UTC.
  const instant = instantAt(date, 9 * 60, 180);
  assert.equal(instant.toISOString(), '2026-09-17T06:00:00.000Z');
});

test('an instant reports the local date it falls on', () => {
  // Half past eleven at night UTC is half past two the *next* morning at
  // +03:00 — the case that puts a booking on the wrong day of the calendar.
  assert.equal(localDateOf(new Date('2026-09-17T23:30:00.000Z'), 180), '2026-09-18');
  assert.equal(localDateOf(new Date('2026-09-17T06:00:00.000Z'), 180), '2026-09-17');
});

test('weekday is 0=Sunday, matching the client and the hours table', () => {
  // 2026-09-17 is a Thursday.
  assert.equal(weekdayOf(parseLocalDate('2026-09-17')!), 4);
  assert.equal(weekdayOf(parseLocalDate('2026-09-20')!), 0, 'Sunday');
  assert.equal(weekdayOf(parseLocalDate('2026-09-19')!), 6, 'Saturday');
});

// ── Opening hours ───────────────────────────────────────────────────────────

test('a closed day has no working window', () => {
  assert.deepEqual(
    openWindows({ isClosed: true, opensAt: '09:00', closesAt: '20:00' }),
    [],
  );
  assert.deepEqual(openWindows(null), []);
  assert.deepEqual(openWindows(undefined), []);
});

test('a day that closes before it opens is not a day', () => {
  // Enterable by a salon owner, and it must not produce a negative window that
  // yields slots running backwards.
  assert.deepEqual(
    openWindows({ isClosed: false, opensAt: '20:00', closesAt: '09:00' }),
    [],
  );
  assert.deepEqual(
    openWindows({ isClosed: false, opensAt: 'nine', closesAt: '20:00' }),
    [],
  );
});

test('a midday break splits the day in two', () => {
  assert.deepEqual(
    openWindows({
      isClosed: false,
      opensAt: '09:00',
      closesAt: '20:00',
      breakStartsAt: '13:00',
      breakEndsAt: '15:00',
    }),
    [
      { from: 540, to: 780 },
      { from: 900, to: 1200 },
    ],
  );
});

test('a nonsense break costs the salon its lunch hour, never its afternoon', () => {
  const day = {
    isClosed: false,
    opensAt: '09:00',
    closesAt: '20:00',
  };
  // Inverted, outside the day, half-entered — each ignored rather than
  // honoured, because honouring them closes the salon.
  for (const broken of [
    { breakStartsAt: '15:00', breakEndsAt: '13:00' },
    { breakStartsAt: '21:00', breakEndsAt: '22:00' },
    { breakStartsAt: '13:00', breakEndsAt: null },
    { breakStartsAt: 'noon', breakEndsAt: '15:00' },
  ]) {
    assert.deepEqual(
      openWindows({ ...day, ...broken }),
      [{ from: 540, to: 1200 }],
      JSON.stringify(broken),
    );
  }
});

// ── The grid ────────────────────────────────────────────────────────────────

test('a service must finish before closing, not merely start before it', () => {
  // 09:00–10:00, 30-minute grid, 45-minute service. 09:00 fits; 09:30 would
  // run to 10:15 and does not.
  const starts = candidateStarts([{ from: 540, to: 600 }], 30, 45);
  assert.deepEqual(starts.map(timeOfDay), ['09:00']);
});

test('starts are aligned to the grid from midnight', () => {
  // A salon opening at 09:10 on a half-hour grid offers 09:30, not 09:10 —
  // otherwise every salon has its own private set of odd minutes.
  const starts = candidateStarts([{ from: 550, to: 720 }], 30, 60);
  assert.deepEqual(starts.map(timeOfDay), ['09:30', '10:00', '10:30', '11:00']);
});

test('a service longer than the whole window yields nothing', () => {
  assert.deepEqual(candidateStarts([{ from: 540, to: 600 }], 30, 90), []);
});

test('each side of a break is offered separately', () => {
  const windows = openWindows({
    isClosed: false,
    opensAt: '09:00',
    closesAt: '12:00',
    breakStartsAt: '10:00',
    breakEndsAt: '11:00',
  });
  assert.deepEqual(
    candidateStarts(windows, 60, 60).map(timeOfDay),
    ['09:00', '11:00'],
  );
});

// ── Overlap ─────────────────────────────────────────────────────────────────

test('the overlap rule is half-open, so back-to-back bookings do not clash', () => {
  // 09:00–10:00 and 10:00–11:00 are two appointments, not a conflict. This is
  // the single most important line in the file: a closed interval here would
  // halve every salon's capacity.
  assert.equal(overlaps(540, 600, 600, 660), false);
  assert.equal(overlaps(600, 660, 540, 600), false);

  assert.equal(overlaps(540, 600, 570, 630), true, 'partial');
  assert.equal(overlaps(540, 660, 570, 600), true, 'contained');
  assert.equal(overlaps(570, 600, 540, 660), true, 'containing');
  assert.equal(overlaps(540, 600, 540, 600), true, 'identical');
});
