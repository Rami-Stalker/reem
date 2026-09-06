import { BlockWeights } from './visual-descriptor';
import { RawImage, SignalReadings } from './image-signals';

/** DI token for the embedder the platform is currently indexing with. */
export const VISUAL_EMBEDDER = Symbol('VISUAL_EMBEDDER');

/**
 * What a photograph is being handed to an embedder as.
 *
 * Both forms, always. The local descriptor wants decoded pixels and would pay
 * to decode them twice; a hosted model wants the encoded file and cannot use
 * a raw buffer at all. Preparing both once, in `ImageProcessingService`, is
 * cheaper than either implementation reaching for what it needs on its own.
 */
export interface EmbeddableImage {
  /** Re-encoded, EXIF-stripped, bounded. Safe to send to a third party. */
  buffer: Buffer;
  /** The decoded square canvas, for a local descriptor. */
  raw: RawImage;
  /** SHA-256 of `buffer`. The cache key everywhere downstream. */
  checksum: string;
}

export interface VisualDescriptorResult {
  vector: number[];
  /**
   * The interpretable signals, when the embedder produces any. Null from a
   * hosted model that returns only a vector — the attribute layer then works
   * from whatever the vision analyser said, and from the catalogue neighbours,
   * rather than from the descriptor.
   */
  readings: SignalReadings | null;
}

export interface SimilarityBreakdown {
  /** 0–1, and the only number the ranker orders on. */
  total: number;
  /**
   * The parts it was made of, keyed by whatever the embedder calls them. Kept
   * out of the ranker's way and rendered only into the reason sentence and the
   * debug payload — but *stored*, because a similarity nobody can take apart
   * is a similarity nobody can defend to a seller.
   */
  parts: Record<string, number>;
}

/**
 * The seam a better model plugs into.
 *
 * The interface is wider than "give me a vector" on purpose: comparison and
 * calibration belong to the implementation, not to the caller. A descriptor
 * built from five blocks and a 512-dimension learned embedding do not agree
 * about what a cosine of 0.8 means, and the caller must never have to know.
 *
 * Everything else in this module is written against these four members, so
 * introducing CLIP — or a hosted embedding API, or pgvector with a different
 * index — is a new class and one line of configuration. Rows written by the
 * old embedder stay valid under their own `embedder` name and are simply not
 * read any more.
 */
export interface VisualEmbedder {
  /** Stamped on every row. Two embedders' vectors are never comparable. */
  readonly name: string;
  readonly dimensions: number;

  /**
   * The cosines that map to 0% and 100% on a card. See
   * `displayedSimilarity` — the anchors are a property of the descriptor
   * family, so each implementation states its own.
   */
  readonly anchors: { floor: number; ceiling: number };

  embed(image: EmbeddableImage): Promise<VisualDescriptorResult>;

  /**
   * Compares two stored vectors. `weights` is the query-specific re-weighting
   * — how "the same dress but in black" is expressed — and an implementation
   * that cannot honour it is free to ignore it.
   */
  similarity(
    a: readonly number[],
    b: readonly number[],
    weights?: Partial<BlockWeights>,
  ): SimilarityBreakdown;
}
