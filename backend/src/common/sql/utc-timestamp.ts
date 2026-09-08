import { Prisma } from '@prisma/client';

/**
 * A `Date` bound into raw SQL so it means what Prisma means by it.
 *
 * **The bug this exists to stop.** Every `DateTime` column in this schema is
 * `timestamp without time zone`, and Prisma writes UTC into them. A JavaScript
 * `Date` passed as a query parameter, though, arrives as `timestamptz` — an
 * instant — and comparing an instant against a naive timestamp makes
 * PostgreSQL convert one of them using the *session's* `TimeZone`. On a server
 * set to `Europe/Istanbul` that silently shifts the value three hours:
 *
 * ```
 *   SELECT $1::timestamptz AT TIME ZONE 'UTC'   -- 2026-09-07 22:30:00  ✓ correct
 *   SELECT $1::timestamp                        -- 2026-09-08 01:30:00  ✗ shifted
 * ```
 *
 * Nothing raises. The query returns rows — the wrong rows — and a report
 * quietly covers a window three hours away from the one that was asked for.
 * Prisma's own `where: { createdAt: { gte } }` filters are unaffected, so the
 * two ways of asking the same question disagree, and only the raw one is
 * wrong.
 *
 * It is also invisible in CI, which is why it survived: the `postgres:18`
 * container runs UTC, where the shift is zero. It only appears on a developer's
 * machine or a production server in a real timezone — the places where nobody
 * is running assertions.
 *
 * So: never interpolate a bare `Date` into raw SQL that touches a timestamp
 * column. Use this, which sends the instant as text and converts it back in
 * UTC, giving exactly the wall-clock value Prisma stored.
 *
 * The fragment is bracketed, and that is not decoration. `::` binds tighter
 * than `AT TIME ZONE`, so an unbracketed fragment followed by a cast to date
 * parses as `X AT TIME ZONE ('UTC'::date)` and dies with "invalid input syntax
 * for type date: UTC". Bracketing here means no call site has to know that.
 */
export function utcTimestamp(value: Date): Prisma.Sql {
  return Prisma.sql`(${value.toISOString()}::timestamptz AT TIME ZONE 'UTC')`;
}

/**
 * The same conversion for `$queryRawUnsafe`, which takes positional parameters
 * rather than a tagged template.
 *
 * Pass `utcParam(date)` as the parameter and write the placeholder as
 * `` `${utcCast('$3')}` `` in the statement.
 */
export function utcParam(value: Date): string {
  return value.toISOString();
}

/** The cast to wrap a positional placeholder in. See {@link utcParam}. */
export function utcCast(placeholder: string): string {
  return `(${placeholder}::timestamptz AT TIME ZONE 'UTC')`;
}
