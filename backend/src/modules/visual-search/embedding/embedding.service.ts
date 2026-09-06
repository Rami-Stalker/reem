import { Inject, Injectable } from '@nestjs/common';
import { CacheService } from '../../../common/cache/cache.service';
import { ImageProcessingService, PreparedImage } from '../processing/image-processing.service';
import { nearestColourKey, readingsToAttributes } from '../understanding/visual-attributes';
import { hsvToRgb } from '../understanding/visual-attributes';
import { VISUAL_EMBEDDER, VisualEmbedder } from './visual-embedder';
import { SignalReadings } from './image-signals';

export interface Embedding {
  vector: number[];
  readings: SignalReadings | null;
  /** Lexicon colour keys in dominance order, for the palette pre-filter. */
  paletteKeys: string[];
  /** `plain` | `textured` | `patterned`, or null without readings. */
  pattern: string | null;
}

/**
 * The one place a photograph becomes a vector.
 *
 * Thin on purpose — it owns the cache and the derived palette, and delegates
 * everything else. Two callers need exactly this and nothing more: the query
 * path, which embeds once per search, and the indexer, which embeds once per
 * catalogue photograph.
 *
 * The cache is keyed by content hash rather than by URL or by session, which
 * is what makes it worth having. She screenshots the same dress from three
 * apps and uploads it twice; a seller relists a product with the photograph
 * already on another listing. Both are the same bytes, and the second one is
 * free.
 */
@Injectable()
export class EmbeddingService {
  /**
   * Ten minutes. Long enough to cover a refinement thread — she uploads, then
   * types three sentences at it — and short enough that a process holding a
   * few thousand of these never becomes the reason the API is memory-bound.
   */
  private static readonly TTL_MS = 10 * 60 * 1000;

  constructor(
    @Inject(VISUAL_EMBEDDER) private readonly embedder: VisualEmbedder,
    private readonly processing: ImageProcessingService,
    private readonly cache: CacheService,
  ) {}

  get name(): string {
    return this.embedder.name;
  }

  get dimensions(): number {
    return this.embedder.dimensions;
  }

  get anchors(): { floor: number; ceiling: number } {
    return this.embedder.anchors;
  }

  /** Embeds an image already through `ImageProcessingService`. */
  async embed(prepared: PreparedImage): Promise<Embedding> {
    const key = `visual:embed:${this.embedder.name}:${prepared.checksum}`;
    return this.cache.wrap(key, EmbeddingService.TTL_MS, async () => {
      const result = await this.embedder.embed(prepared);
      return {
        vector: result.vector,
        readings: result.readings,
        paletteKeys: paletteFrom(result.readings),
        pattern: result.readings
          ? readingsToAttributes(result.readings).pattern
          : null,
      };
    });
  }

  /** Decode-and-embed in one step, for a caller holding raw bytes. */
  async embedBytes(
    bytes: Buffer,
    options: { withFrame?: boolean } = {},
  ): Promise<{ prepared: PreparedImage; embedding: Embedding }> {
    const prepared = await this.processing.prepare(bytes, options);
    return { prepared, embedding: await this.embed(prepared) };
  }
}

/**
 * The palette keys stored beside a vector.
 *
 * Denormalised from the readings so the candidate pull can pre-filter on
 * colour without decoding 184 floats per row — the single largest saving in
 * the whole search path, and the reason a black dress does not get compared
 * against every handbag in the shop.
 */
export function paletteFrom(readings: SignalReadings | null): string[] {
  if (!readings) return [];

  const keys: string[] = [];
  for (const entry of readings.palette) {
    if (entry.share < 0.06) continue;
    const key = nearestColourKey(
      hsvToRgb(entry.hue ?? 0, entry.hue === null ? 0 : entry.saturation, entry.lightness),
    );
    if (key && !keys.includes(key)) keys.push(key);
    if (keys.length === 4) break;
  }
  return keys;
}
