import { Transform } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

/**
 * Keyset pagination for feeds.
 *
 * Offset paging is right for a list that sits still — an order history, an
 * admin table — and wrong for a feed, which grows at the head. Between the
 * moment she loads page one and the moment she reaches the bottom, three new
 * posts have been published, every row has shifted, and page two shows her two
 * she has already seen and skips one she has not. It also gets slower with
 * depth, because `OFFSET 200` means reading and discarding two hundred rows.
 *
 * So the cursor names the last row she saw, and the next page is everything
 * strictly after it. `PaginationDto` stays for the admin lists and for the
 * legacy `/posts/*` contract, whose envelope promises `total` and
 * `total_pages` — numbers a keyset page cannot honestly produce.
 */
export class CursorPageDto {
  /**
   * Opaque. It encodes a timestamp and an id, and the client's only correct
   * behaviour is to send back what it was given — which is exactly why it is
   * base64 rather than two readable query parameters somebody would be tempted
   * to construct by hand.
   */
  @IsOptional()
  @IsString()
  @MaxLength(256)
  cursor?: string;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(50)
  limit: number = 20;
}

export interface Cursor {
  at: Date;
  id: string;
}

/**
 * The far future, so a first page has something to compare against.
 *
 * Year 9999 rather than JavaScript's maximum date. `new Date(8.64e15)` is the
 * year 275760, whose ISO form carries a leading `+` — and Prisma refuses to
 * bind it as a timestamp at all, so every first page came back a 500.
 */
const FAR_FUTURE = new Date('9999-12-31T23:59:59.999Z');

/** A uuid sorts below this, so a first page's tie-break admits everything. */
const HIGH_ID = 'ffffffff-ffff-ffff-ffff-ffffffffffff';

export function encodeCursor(at: Date, id: string): string {
  return Buffer.from(`${at.toISOString()}|${id}`, 'utf8').toString('base64url');
}

/**
 * A malformed cursor reads as "start from the beginning" rather than as an
 * error. It is a value the client is supposed to echo, so the only ways it
 * arrives broken are a truncated URL or a stale bookmark — and answering
 * either with a 400 turns a cosmetic problem into an empty screen.
 */
export function decodeCursor(raw: string | undefined): Cursor {
  if (!raw) return { at: FAR_FUTURE, id: HIGH_ID };
  try {
    const [iso, id] = Buffer.from(raw, 'base64url').toString('utf8').split('|');
    const at = new Date(iso);
    if (Number.isNaN(at.getTime()) || !id) {
      return { at: FAR_FUTURE, id: HIGH_ID };
    }
    return { at, id };
  } catch {
    return { at: FAR_FUTURE, id: HIGH_ID };
  }
}

/**
 * The envelope. `next_cursor` is null exactly when there is no next page, so
 * the client never has to guess from a short page — a page can be short
 * because rows were filtered out after the database returned them.
 */
export interface CursorMeta {
  limit: number;
  has_next_page: boolean;
  next_cursor: string | null;
}

export function buildCursorMeta(
  limit: number,
  hasMore: boolean,
  last: { at: Date; id: string } | null,
): CursorMeta {
  return {
    limit,
    has_next_page: hasMore,
    next_cursor: hasMore && last ? encodeCursor(last.at, last.id) : null,
  };
}
