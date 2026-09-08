import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { searchKey } from './arabic';

/**
 * How long an expansion table may be trusted without re-reading it.
 *
 * Synonyms change when a merchandiser adds one, which is a handful of times a
 * week at most, and they are read on every single search. A minute of
 * staleness is invisible to her — she refreshes and tries the query again —
 * and it keeps the search path from opening a second round trip per keystroke
 * on the suggestions endpoint.
 */
const TTL_MS = 60_000;

/** The alternatives a phrase may also be matched against. */
export interface Expansion {
  /** Other ways to say the whole phrase — «شنطة يد» when «حقيبة يد» is a group. */
  phrases: string[];
  /** Other ways to say a single word inside it — «حقيبة» for «شنطة». */
  words: string[];
}

const EMPTY: Expansion = { phrases: [], words: [] };

/**
 * Turns what a customer typed into the other words she might have typed.
 *
 * Folding makes every spelling of one word agree; it cannot make two words
 * agree. شنطة and حقيبة are both correct, both common, and share not one
 * letter — so a shop whose listings all say حقيبة is invisible to half its
 * customers, and no amount of typo tolerance would have found it. The mapping
 * has to be stated, and it is stated in `search_synonym_groups`.
 *
 * Expansion runs on keys, not words: the group's terms are stored already
 * folded, and the query is folded before lookup, so «شَنْطَة» finds the group
 * that was seeded with «شنطة».
 */
@Injectable()
export class SynonymsService {
  private readonly logger = new Logger(SynonymsService.name);

  /** key → every other key that means the same thing. */
  private table = new Map<string, string[]>();
  private loadedAt = 0;
  private loading: Promise<void> | null = null;

  constructor(private readonly prisma: PrismaService) {}

  /**
   * What else this phrase could have been called.
   *
   * The whole phrase and each of its words are looked up separately, because
   * both kinds of group exist: «عباية» is one word with siblings, and a
   * merchandiser may equally group a two-word phrase. Nothing is recombined
   * across words — expanding «شنطة يد» into every pairing of every synonym of
   * each word multiplies out fast and buys almost nothing, since a listing
   * that says حقيبة يد is already reached by the word-level alternative.
   */
  async expand(query: string | null | undefined): Promise<Expansion> {
    const key = searchKey(query);
    if (!key) return EMPTY;

    await this.ensureLoaded();
    if (this.table.size === 0) return EMPTY;

    const phrases = this.table.get(key) ?? [];

    const words = new Set<string>();
    const parts = key.split(' ').filter(Boolean);
    // A single-word query is its own phrase; looking it up twice would list
    // every sibling under both headings and score the same product twice.
    if (parts.length > 1) {
      for (const part of parts) {
        for (const sibling of this.table.get(part) ?? []) words.add(sibling);
      }
    }

    return { phrases, words: [...words] };
  }

  /** Drops the cache so a merchandiser's edit takes effect on her next search. */
  invalidate(): void {
    this.loadedAt = 0;
  }

  private async ensureLoaded(): Promise<void> {
    if (Date.now() - this.loadedAt < TTL_MS) return;
    // One in-flight load, however many searches arrive during it.
    this.loading ??= this.load().finally(() => {
      this.loading = null;
    });
    await this.loading;
  }

  private async load(): Promise<void> {
    try {
      const groups = await this.prisma.searchSynonymGroup.findMany({
        where: { isActive: true },
        select: { terms: { select: { termKey: true } } },
      });

      const table = new Map<string, string[]>();
      for (const group of groups) {
        const keys = group.terms.map((t) => t.termKey).filter(Boolean);
        if (keys.length < 2) continue; // A group of one expands to nothing.
        for (const key of keys) {
          table.set(
            key,
            keys.filter((other) => other !== key),
          );
        }
      }

      this.table = table;
      this.loadedAt = Date.now();
    } catch (error) {
      // A search must not fail because the thesaurus is unreachable. The
      // previous table stays in place, and the worst case is a query matched
      // on its literal words — which is exactly what happened before this
      // service existed.
      this.logger.warn(`Synonyms not reloaded: ${String(error)}`);
      this.loadedAt = Date.now();
    }
  }
}
