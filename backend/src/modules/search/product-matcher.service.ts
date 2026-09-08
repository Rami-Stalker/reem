import { Injectable } from '@nestjs/common';
import { ProductStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { searchKey } from './arabic';
import { SynonymsService } from './synonyms.service';

/** One product the text query reached, and how well. */
export interface ProductMatch {
  id: string;
  score: number;
}

/**
 * How many products a single text query may put forward.
 *
 * The matcher answers "which products does this phrase reach", and the
 * filters, sorting and paging that follow are applied by the caller in
 * Prisma. That split is deliberate — it keeps `PURCHASABLE_PRODUCT_WHERE` and
 * the price and category filters in the one place they are defined, instead
 * of re-spelling them in SQL where they would drift — but it means the
 * candidate list has to be bounded, because it is carried back as an `IN`.
 *
 * 400 is far past what anyone pages through and small enough to stay cheap.
 * A query broad enough to reach more than 400 products is a query nobody is
 * reading to the bottom of, and the cut is by relevance, so what is dropped
 * is the tail.
 */
const MAX_CANDIDATES = 400;

/**
 * Which products a phrase reaches, and in what order.
 *
 * Matching used to be `ILIKE '%q%'` on the raw title and description, which
 * had two problems. It could not match Arabic that was spelled differently
 * from the listing — see `arabic.ts` — and, because a leading wildcard is
 * unindexable, every search read the whole catalogue.
 *
 * Both sides are put through `reem_search_key` now, and the trigram indexes
 * created with it serve both the substring test and the similarity test that
 * gives typo tolerance.
 *
 * The ranking is tiered rather than a single similarity score, because
 * similarity alone ranks badly for the commonest case: a short query inside a
 * long title scores low on trigram overlap, so «فستان» typed against «فستان
 * سهرة طويل مطرز» would have been beaten by any short title it merely
 * resembled. An exact hit outranks a prefix, a prefix outranks a substring, a
 * title outranks a description, and fuzzy matches sit below all of them —
 * which is the order a customer would put them in.
 */
@Injectable()
export class ProductMatcher {
  constructor(
    private readonly prisma: PrismaService,
    private readonly synonyms: SynonymsService,
  ) {}

  /**
   * Returns null when there is no text to match on, which is different from
   * returning an empty list: no query means "every product, filtered", and an
   * empty list means "nothing matched". Collapsing the two would turn a
   * blank search box into an empty shop.
   */
  async match(query: string | null | undefined): Promise<ProductMatch[] | null> {
    const key = searchKey(query);
    if (!key) return null;

    // The other words she might have used. Passed as arrays rather than folded
    // into the SQL text so the query plan is reused whatever the vocabulary
    // holds, and so a synonym a merchandiser typed can never be a fragment of
    // a statement.
    const { phrases, words } = await this.synonyms.expand(query);

    const rows = await this.prisma.$queryRawUnsafe<
      { id: string; score: number }[]
    >(
      `
      WITH q AS (SELECT $1::text AS key, $4::text[] AS alts)
      SELECT p.id,
             GREATEST(
               -- The phrase IS the title.
               CASE WHEN reem_search_key(p.title) = q.key THEN 1.0 ELSE 0 END,
               -- The title opens with it.
               CASE WHEN reem_search_key(p.title) LIKE q.key || '%' THEN 0.9 ELSE 0 END,
               -- The title carries it somewhere.
               CASE WHEN reem_search_key(p.title) LIKE '%' || q.key || '%' THEN 0.8 ELSE 0 END,
               -- The title carries another word for the same thing. Below a
               -- literal hit and above the description, because a shopper who
               -- typed شنطة is better served by a حقيبة in the title than by
               -- her own word buried in a paragraph — but if something says
               -- شنطة outright, that comes first.
               CASE WHEN EXISTS (
                      SELECT 1 FROM unnest(q.alts) AS a(term)
                      WHERE reem_search_key(p.title) LIKE '%' || a.term || '%'
                    ) THEN 0.7 ELSE 0 END,
               -- The description mentions it.
               CASE WHEN reem_search_key(p.description) LIKE '%' || q.key || '%' THEN 0.6 ELSE 0 END,
               -- Or some word of the title is close enough to be a typo of it.
               -- Banded into [0.43, 0.55] so a typo never outranks a garment
               -- that genuinely carries the word.
               (0.25 + word_similarity(q.key, reem_search_key(p.title)) * 0.3)
                 * CASE WHEN q.key <% reem_search_key(p.title) THEN 1 ELSE 0 END
             )::float8 AS score
      FROM products p, q
      WHERE p.status = $2::"ProductStatus"
        AND (
             reem_search_key(p.title) LIKE '%' || q.key || '%'
          OR reem_search_key(p.description) LIKE '%' || q.key || '%'
          -- Word similarity, not whole-string similarity: it asks whether
          -- any single word of the title is a near match. Comparing the query
          -- against the entire title scored «فستاان» at 0.38 against «فستان
          -- سهرة» — the second word diluting the first — and a longer title
          -- would have pushed it under the threshold entirely. The typo a
          -- customer makes is in one word, so one word is what is compared.
          OR q.key <% reem_search_key(p.title)
          OR EXISTS (
               SELECT 1 FROM unnest(q.alts) AS a(term)
               WHERE reem_search_key(p.title) LIKE '%' || a.term || '%'
                  OR reem_search_key(p.description) LIKE '%' || a.term || '%'
             )
        )
      ORDER BY score DESC, p.orders_count DESC, p.created_at DESC
      LIMIT $3
      `,
      key,
      ProductStatus.ACTIVE,
      MAX_CANDIDATES,
      [...phrases, ...words],
    );

    // No second filter: what matched is decided by the WHERE clause, once.
    // A floor over the *scaled* score used to sit here and quietly threw away
    // the typos the clause had just admitted, because a fuzzy score banded
    // below the substring tiers can never clear a threshold meant for raw
    // similarity. One gate, in one place.
    return rows;
  }

  /** Titles to offer as you type, most relevant first. */
  async suggest(query: string | null | undefined, take = 8): Promise<string[]> {
    const key = searchKey(query);
    if (!key) return [];

    const rows = await this.prisma.$queryRawUnsafe<{ title: string }[]>(
      `
      WITH q AS (SELECT $1::text AS key)
      SELECT p.title
      FROM products p, q
      WHERE p.status = $2::"ProductStatus"
        AND (
             reem_search_key(p.title) LIKE '%' || q.key || '%'
          OR q.key <% reem_search_key(p.title)
        )
      ORDER BY
        CASE WHEN reem_search_key(p.title) LIKE q.key || '%' THEN 0 ELSE 1 END,
        word_similarity(q.key, reem_search_key(p.title)) DESC,
        p.orders_count DESC
      LIMIT $3
      `,
      key,
      ProductStatus.ACTIVE,
      take,
    );
    return rows.map((row) => row.title);
  }

  /** Categories whose Arabic name the phrase reaches. */
  async matchCategories(
    query: string | null | undefined,
    take = 5,
  ): Promise<{ slug: string; name: string }[]> {
    const key = searchKey(query);
    if (!key) return [];

    return this.prisma.$queryRawUnsafe<{ slug: string; name: string }[]>(
      `
      WITH q AS (SELECT $1::text AS key)
      SELECT c.slug, c.name_ar AS name
      FROM categories c, q
      WHERE c.is_active
        AND (
             reem_search_key(c.name_ar) LIKE '%' || q.key || '%'
          OR reem_search_key(c.name_en) LIKE '%' || q.key || '%'
          OR reem_search_key(c.slug)    LIKE '%' || q.key || '%'
          OR q.key <% reem_search_key(c.name_ar)
        )
      ORDER BY
        CASE WHEN reem_search_key(c.name_ar) LIKE q.key || '%' THEN 0 ELSE 1 END,
        word_similarity(q.key, reem_search_key(c.name_ar)) DESC
      LIMIT $2
      `,
      key,
      take,
    );
  }

  /**
   * Posts and reels the phrase reaches — by their own words, or by the title
   * of a product they tag.
   */
  async matchContentIds(
    query: string | null | undefined,
    take = 200,
  ): Promise<string[] | null> {
    const key = searchKey(query);
    if (!key) return null;

    const rows = await this.prisma.$queryRawUnsafe<{ id: string }[]>(
      `
      WITH q AS (SELECT $1::text AS key)
      SELECT c.id
      FROM commerce_contents c, q
      WHERE reem_search_key(c.title) LIKE '%' || q.key || '%'
         OR reem_search_key(c.body)  LIKE '%' || q.key || '%'
         OR q.key <% reem_search_key(c.title)
         OR EXISTS (
              SELECT 1
              FROM commerce_content_product_tags t
              JOIN products p ON p.id = t.product_id
              WHERE t.content_id = c.id
                AND reem_search_key(p.title) LIKE '%' || q.key || '%'
            )
      LIMIT $2
      `,
      key,
      take,
    );
    return rows.map((row) => row.id);
  }

  /** Boutiques whose name the phrase reaches. */
  async matchSellerIds(
    query: string | null | undefined,
    take = 100,
  ): Promise<string[] | null> {
    const key = searchKey(query);
    if (!key) return null;

    const rows = await this.prisma.$queryRawUnsafe<{ id: string }[]>(
      `
      WITH q AS (SELECT $1::text AS key)
      SELECT u.id
      FROM users u, q
      WHERE u.role = 'SELLER'
        AND (
             reem_search_key(u.name)     LIKE '%' || q.key || '%'
          OR reem_search_key(u.username) LIKE '%' || q.key || '%'
          OR q.key <% reem_search_key(u.name)
        )
      ORDER BY
        CASE WHEN reem_search_key(u.name) LIKE q.key || '%' THEN 0 ELSE 1 END,
        u.followers_count DESC
      LIMIT $2
      `,
      key,
      take,
    );
    return rows.map((row) => row.id);
  }
}
