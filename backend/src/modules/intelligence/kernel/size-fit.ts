/**
 * How often a size was kept.
 *
 * The answer a product page owes the woman choosing between M and L, and the
 * one a fitting room gives and a listing never does: of the pieces in this
 * size that reached someone, how many stayed. A return marked `SIZE_ISSUE`
 * is the only reliable signal the platform has about fit, and it is about
 * the size she *received* — so it counts against that size, whether it ended
 * in a refund or an exchange.
 *
 * What it will not say is as important:
 *
 * - **No rate below the sample floor.** Three sales and one return is not
 *   "67% kept", it is noise, and on a small boutique it is close to naming
 *   the woman who sent it back. A size under [MIN_FIT_SAMPLE] units reports
 *   `null`, and the page says nothing about it.
 * - **No direction.** `SIZE_ISSUE` does not record whether the piece was too
 *   small or too large, so nothing here claims a piece "runs small".
 * - **No volumes.** Only the rate leaves the kernel's caller. How many units
 *   of each size a boutique sold is her business, not the shopper's.
 */

/** One size's raw counts, in units. */
export interface SizeSales {
  size: string;
  /** Units in this size that reached the customer. */
  delivered: number;
  /** Of those, units returned or exchanged because of the size. */
  returnedForSize: number;
}

export interface SizeFit {
  size: string;
  /** Share of delivered units kept, 0–1, or `null` below the sample floor. */
  keptRate: number | null;
}

/** Units a size must have reached customers in before it gets a rate. */
export const MIN_FIT_SAMPLE = 10;

/** Letter sizes in the order a size row reads. */
const LETTER_ORDER = ['XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];

/** The size as one spelling: `" m "`, `"M"` and `"m"` are the same size. */
export function normaliseSize(raw: unknown): string | null {
  if (typeof raw !== 'string' && typeof raw !== 'number') return null;
  const size = String(raw).trim().toUpperCase().replace(/\s+/g, ' ');
  if (size.length === 0) return null;
  // «2XL» and «XXL» are written both ways on the same platform.
  const multiX = /^([2-3])XL$/.exec(size);
  return multiX ? `${'X'.repeat(Number(multiX[1]))}L` : size;
}

function sizeRank(size: string): [number, number, string] {
  const letter = LETTER_ORDER.indexOf(size);
  if (letter >= 0) return [0, letter, size];
  const numeric = Number(size);
  if (Number.isFinite(numeric)) return [1, numeric, size];
  return [2, 0, size];
}

/**
 * Kept rates per size, merged across spellings and across every other option
 * (an M in red and an M in navy are the same M), in size-row order.
 */
export function sizeFit(
  sales: SizeSales[],
  minSample: number = MIN_FIT_SAMPLE,
): SizeFit[] {
  const merged = new Map<string, { delivered: number; returned: number }>();
  for (const row of sales) {
    const size = normaliseSize(row.size);
    if (size === null) continue;
    const entry = merged.get(size) ?? { delivered: 0, returned: 0 };
    entry.delivered += Math.max(0, row.delivered);
    entry.returned += Math.max(0, row.returnedForSize);
    merged.set(size, entry);
  }

  return [...merged.entries()]
    .sort(([a], [b]) => {
      const [ka, va, sa] = sizeRank(a);
      const [kb, vb, sb] = sizeRank(b);
      return ka - kb || va - vb || sa.localeCompare(sb);
    })
    .map(([size, { delivered, returned }]) => ({
      size,
      keptRate:
        delivered < minSample
          ? null
          : // A return can outnumber what was delivered only through bad data;
            // it never makes the rate negative.
            Math.round(
              (Math.max(0, delivered - Math.min(returned, delivered)) /
                delivered) *
                100,
            ) / 100,
    }));
}
