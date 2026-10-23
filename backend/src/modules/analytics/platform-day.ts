import { PLATFORM_TIMEZONE } from '../customer-intelligence/customer-facts.service';

/**
 * Calendar days as the platform lives them.
 *
 * Reports bucket by the day in Damascus, not in UTC: an order placed at
 * 1am local time belongs to that morning's figures, and a UTC bucket filed it
 * under the previous evening.
 */
const platformDay = new Intl.DateTimeFormat('en-CA', {
  timeZone: PLATFORM_TIMEZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

/** `2026-10-22`, as the day reads in Damascus — not in UTC. */
export function dayLabel(at: Date): string {
  return platformDay.format(at);
}

/**
 * Every calendar day the range touches, oldest first.
 *
 * A chart drawn only from the days that had orders joins Monday to Thursday
 * with a straight line and hides the two empty days between them — which, on
 * a revenue trend, are the days that matter.
 */
export function daysIn(range: { start: Date; end: Date }): string[] {
  const labels = new Set<string>();
  const step = 6 * 3_600_000;
  for (let t = range.start.getTime(); t <= range.end.getTime(); t += step) {
    labels.add(dayLabel(new Date(t)));
  }
  labels.add(dayLabel(range.end));
  return [...labels];
}

/** Midnight today, in the platform's timezone, as an instant. */
export function startOfPlatformDay(now = new Date()): Date {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: PLATFORM_TIMEZONE,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(now);
  const get = (type: string) =>
    Number(parts.find((part) => part.type === type)?.value ?? 0);
  const wallClock = Date.UTC(
    get('year'),
    get('month') - 1,
    get('day'),
    get('hour'),
    get('minute'),
    get('second'),
  );
  const offset = Math.round((wallClock - now.getTime()) / 60_000) * 60_000;
  return new Date(Date.UTC(get('year'), get('month') - 1, get('day')) - offset);
}

