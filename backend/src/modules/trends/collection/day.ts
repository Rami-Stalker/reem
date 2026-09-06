/**
 * Day arithmetic for the Trend Engine.
 *
 * Everything here is UTC, and that is a decision rather than laziness. A
 * `@db.Date` column has no zone, so a "day" has to mean the same thing to the
 * collector, the scorer and the forecaster or a product's history acquires
 * gaps and doubles at every daylight boundary. Damascus is UTC+3 year-round,
 * so a UTC day and a local day differ only in where the seam falls at
 * midnight — and a seam that is stable is worth more here than a seam that is
 * local.
 */

/** Midnight UTC on the day `date` falls in. */
export function startOfDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
}

/** Midnight UTC on the following day — an exclusive upper bound. */
export function endOfDay(date: Date): Date {
  return addDays(startOfDay(date), 1);
}

export function addDays(date: Date, days: number): Date {
  const next = new Date(date.getTime());
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

/** Today at midnight UTC. The one place `new Date()` is called. */
export function utcToday(): Date {
  return startOfDay(new Date());
}

/** `YYYY-MM-DD`. The key every in-memory map of days is built on. */
export function dayKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export function fromDayKey(key: string): Date {
  return new Date(`${key}T00:00:00.000Z`);
}

/** Every day from `from` to `to` inclusive, oldest first. */
export function eachDay(from: Date, to: Date): Date[] {
  const days: Date[] = [];
  let cursor = startOfDay(from);
  const last = startOfDay(to);
  // Guarded rather than `while (true)`: a reversed range should return nothing,
  // not spin.
  while (cursor.getTime() <= last.getTime()) {
    days.push(cursor);
    cursor = addDays(cursor, 1);
  }
  return days;
}

/** The `count` days ending at `to` inclusive, oldest first. */
export function lastDays(to: Date, count: number): Date[] {
  const end = startOfDay(to);
  return eachDay(addDays(end, -(Math.max(1, count) - 1)), end);
}

/** Whole days between two dates, positive when `b` is later. */
export function daysBetween(a: Date, b: Date): number {
  return Math.round(
    (startOfDay(b).getTime() - startOfDay(a).getTime()) / 86_400_000,
  );
}
