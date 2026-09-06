import { Prisma } from '@prisma/client';
import { BlockWeights } from '../embedding/visual-descriptor';

/** DI token for the nearest-neighbour store the platform is searching in. */
export const VECTOR_INDEX = Symbol('VECTOR_INDEX');

export interface VectorRecord {
  productId: string;
  mediaUrl: string;
  position: number;
  vector: number[];
  paletteKeys: string[];
  pattern: string | null;
  sourceChecksum: string | null;
}

export interface VectorMatch {
  productId: string;
  mediaUrl: string;
  position: number;
  /** Raw, uncalibrated similarity from the embedder. 0–1. */
  similarity: number;
  /** The per-block breakdown, for the reason sentence and for auditing. */
  parts: Record<string, number>;
  paletteKeys: string[];
  pattern: string | null;
}

export interface VectorSearchOptions {
  /**
   * The hard constraints, as Prisma. Always includes
   * `PURCHASABLE_PRODUCT_WHERE`; a visual search that returns things nobody
   * sells is a worse answer than one that returns fewer things.
   */
  productWhere: Prisma.ProductWhereInput;

  /**
   * Colour keys worth preferring in the candidate pull. Not a filter on the
   * result — see the two-pass note in the Postgres implementation.
   */
  paletteKeys?: readonly string[];

  /** Query-specific block weights. See `weightsForQuery`. */
  weights?: Partial<BlockWeights>;

  /** How many rows to score exactly. */
  candidateLimit: number;
  /** How many matches to return. */
  limit: number;
  /** Raw similarity below which a row is not a match at all. */
  minSimilarity: number;

  /** Products already answered for, e.g. by an earlier region. */
  excludeProductIds?: readonly string[];
}

/**
 * Nearest-neighbour search over product image vectors.
 *
 * Deliberately its own interface rather than a method on the search service,
 * because this is the layer most likely to be replaced and the one whose
 * replacement must change nothing above it. Three futures all fit behind it
 * unchanged:
 *
 *  - **pgvector.** The same rows, a `vector` column instead of `double
 *    precision[]`, and an IVFFlat or HNSW index doing the k-NN in the database
 *    instead of in Node. That is the upgrade this shape exists for, and the
 *    only thing it changes is that `candidateLimit` stops mattering.
 *  - **A hosted vector database.** Qdrant, Pinecone, Milvus. `upsert` and
 *    `search` are already their vocabulary.
 *  - **A different distance.** An embedder whose vectors are not
 *    block-structured brings its own `similarity`, and this layer only ever
 *    calls it.
 */
export interface VectorIndex {
  readonly name: string;

  /** Writes or replaces the vectors for one product's images. */
  upsert(productId: string, records: readonly VectorRecord[]): Promise<void>;

  /** Drops every vector for a product — a delisting, or a re-index. */
  remove(productId: string): Promise<number>;

  search(vector: readonly number[], options: VectorSearchOptions): Promise<VectorMatch[]>;

  /** How many vectors the current embedder has indexed. Powers readiness. */
  size(): Promise<number>;
}
