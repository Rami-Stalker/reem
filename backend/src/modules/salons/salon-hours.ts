/**
 * The clock on the wall, and how it becomes an instant.
 *
 * A salon says "we open at nine". That is a fact about local time, not about
 * UTC, and storing it as an instant would make it wrong twice a year and wrong
 * again the moment the platform serves a second country. So opening hours are
 * `HH:mm` strings, and this file is the one place that composes them with a
 * calendar date to produce the real moments a booking can start at.
 *
 * ## The offset
 *
 * Syria is UTC+03:00 and has not observed daylight saving since 2022, so a
 * fixed offset is correct today and this is the single place it is written
 * down. It is configurable (`SALON_UTC_OFFSET_MINUTES`) rather than constant
 * because the first salon outside that offset must be a deployment change and
 * not a code change — and because a reader finding a hard-coded `180` three
 * files deep has no way to know whether it was considered.
 *
 * Everything here is pure: no Prisma, no clock of its own beyond what it is
 * handed. `salon-hours.spec.ts` exercises it directly.
 */

/** `09:30` → 570. Returns null for anything that is not a real time of day. */
export function minutesOfDay(value: string | null | undefined): number | null {
  if (!value) return null;
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(value.trim());
  if (!match) return null;
  return Number(match[1]) * 60 + Number(match[2]);
}

/** 570 → `09:30`. */
export function timeOfDay(minutes: number): string {
  const clamped = Math.max(0, Math.min(24 * 60 - 1, Math.trunc(minutes)));
  const hours = Math.floor(clamped / 60);
  const rest = clamped % 60;
  return `${String(hours).padStart(2, '0')}:${String(rest).padStart(2, '0')}`;
}

/** `2026-09-17` → that date, or null. Rejects a malformed string outright. */
export function parseLocalDate(value: string): { year: number; month: number; day: number } | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value.trim());
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  // Round-tripped so that `2026-02-31` is refused rather than silently rolled
  // into March.
  const probe = new Date(Date.UTC(year, month - 1, day));
  if (
    probe.getUTCFullYear() !== year ||
    probe.getUTCMonth() !== month - 1 ||
    probe.getUTCDate() !== day
  ) {
    return null;
  }
  return { year, month, day };
}

/**
 * A local date and a local time of day, as a real instant.
 *
 * `Date.UTC(...) - offset` rather than `new Date(y, m, d, ...)`: the latter
 * reads the *server's* timezone, which on Render is UTC and on a developer's
 * laptop is whatever they live in — so the same salon would have different
 * opening hours depending on where the process happened to be running.
 */
export function instantAt(
  date: { year: number; month: number; day: number },
  minutes: number,
  offsetMinutes: number,
): Date {
  return new Date(
    Date.UTC(date.year, date.month - 1, date.day, 0, 0, 0, 0) +
      (minutes - offsetMinutes) * 60_000,
  );
}

/** The `YYYY-MM-DD` an instant falls on, in the salon's local reckoning. */
export function localDateOf(instant: Date, offsetMinutes: number): string {
  const shifted = new Date(instant.getTime() + offsetMinutes * 60_000);
  return shifted.toISOString().slice(0, 10);
}

/**
 * Which weekday a local date is, as 0 = Sunday … 6 = Saturday.
 *
 * Matches `SalonWorkingHours.weekday` and, on the client, `DateTime.weekday % 7`
 * — Dart numbers Monday 1 through Sunday 7, so the modulo is what makes the two
 * agree. Getting this wrong shifts every salon's opening hours by a day, which
 * is the kind of bug that looks like bad data.
 */
export function weekdayOf(date: { year: number; month: number; day: number }): number {
  return new Date(Date.UTC(date.year, date.month - 1, date.day)).getUTCDay();
}

export interface DayWindow {
  /** Minutes from local midnight. */
  from: number;
  to: number;
}

export interface WorkingDay {
  isClosed: boolean;
  opensAt: string;
  closesAt: string;
  breakStartsAt?: string | null;
  breakEndsAt?: string | null;
}

/**
 * The stretches of a day a salon is actually working, break removed.
 *
 * Returns an empty list for a closed day, for hours that do not parse, and for
 * a day that closes before it opens — all three of which are data a salon can
 * enter, and none of which should produce a bookable slot. An overnight salon
 * is deliberately not modelled: nothing in this market keeps a chair past
 * midnight, and pretending to support it would make every downstream
 * comparison wrap-around-aware for no one.
 */
export function openWindows(day: WorkingDay | null | undefined): DayWindow[] {
  if (!day || day.isClosed) return [];

  const opens = minutesOfDay(day.opensAt);
  const closes = minutesOfDay(day.closesAt);
  if (opens === null || closes === null || closes <= opens) return [];

  const breakFrom = minutesOfDay(day.breakStartsAt);
  const breakTo = minutesOfDay(day.breakEndsAt);

  // A break that is malformed, inverted, or outside the working day is ignored
  // rather than honoured — a salon should lose its lunch hour in the UI, not
  // its whole afternoon.
  if (
    breakFrom === null ||
    breakTo === null ||
    breakTo <= breakFrom ||
    breakTo <= opens ||
    breakFrom >= closes
  ) {
    return [{ from: opens, to: closes }];
  }

  const windows: DayWindow[] = [];
  if (breakFrom > opens) windows.push({ from: opens, to: breakFrom });
  if (breakTo < closes) windows.push({ from: breakTo, to: closes });
  return windows;
}

/**
 * Every start time a service of [durationMinutes] could occupy inside
 * [windows], stepping by [slotMinutes].
 *
 * The service has to *finish* inside the window: a 45-minute cut cannot start
 * at ten to six when the salon closes at six. That is the whole of the rule,
 * and it is why this takes a duration rather than returning bare grid points.
 */
export function candidateStarts(
  windows: readonly DayWindow[],
  slotMinutes: number,
  durationMinutes: number,
): number[] {
  const step = Math.max(5, Math.trunc(slotMinutes));
  const duration = Math.max(1, Math.trunc(durationMinutes));
  const starts: number[] = [];

  for (const window of windows) {
    // Aligned to the grid from midnight, so a salon opening at 09:00 on a
    // 30-minute grid offers 09:00 and 09:30 rather than 09:07.
    const first = Math.ceil(window.from / step) * step;
    for (let at = first; at + duration <= window.to; at += step) {
      starts.push(at);
    }
  }
  return starts;
}

/** Two half-open intervals, as the booking check asks it. */
export function overlaps(
  aStart: number,
  aEnd: number,
  bStart: number,
  bEnd: number,
): boolean {
  return aStart < bEnd && bStart < aEnd;
}
