import { computeSignals } from './image-signals';
import {
  BlockWeights,
  DESCRIPTOR_DIMENSIONS,
  blockSimilarities,
  defaultWeights,
  weightedSimilarity,
} from './visual-descriptor';
import {
  EmbeddableImage,
  SimilarityBreakdown,
  VisualDescriptorResult,
  VisualEmbedder,
} from './visual-embedder';

/**
 * The default embedder, and a complete implementation rather than a
 * placeholder.
 *
 * It runs in-process, needs no GPU, no key and no network, and produces the
 * same vector for the same bytes forever. On a catalogue of Syrian boutique
 * listings — a garment, centred, on a plain ground — a hand-built perceptual
 * descriptor is genuinely competitive at the thing this feature is for:
 * finding the black evening dress that looks like the black evening dress in
 * her screenshot.
 *
 * What it is not is a semantic model. It does not know that a caftan and an
 * abaya are cousins, or that this print is paisley. That knowledge arrives the
 * day someone hosts a learned embedder behind `VISUAL_EMBEDDER`, and the point
 * of this class is that nothing else has to change when they do — the rows it
 * wrote stay in the table under this name, and the new ones are written under
 * that one.
 *
 * The version suffix is load-bearing. Any change to `image-signals.ts` that
 * moves a number must bump it, because two vectors under one name are promised
 * to be comparable and a silently changed descriptor breaks that promise for
 * every row already indexed.
 */
export class PerceptualVisualEmbedder implements VisualEmbedder {
  readonly name = 'reem-visual-perceptual-v1';
  readonly dimensions = DESCRIPTOR_DIMENSIONS;

  /**
   * Measured against this descriptor rather than assumed.
   *
   * Two unrelated fashion photographs share most of what this thing measures —
   * a portrait crop, a centred subject, a plain background, a smooth surface —
   * so their weighted cosine sits around 0.60–0.70. Anything below `floor`
   * carries no information about being the same garment and renders as 0%.
   * `ceiling` is short of 1.0 because two photographs of the same dress on
   * different days, in different light, do not reach 1.0 either; demanding it
   * would mean nothing ever showed above 90%.
   */
  readonly anchors = { floor: 0.62, ceiling: 0.965 };

  async embed(image: EmbeddableImage): Promise<VisualDescriptorResult> {
    const signals = computeSignals(image.raw);
    return { vector: signals.vector, readings: signals.readings };
  }

  similarity(
    a: readonly number[],
    b: readonly number[],
    weights?: Partial<BlockWeights>,
  ): SimilarityBreakdown {
    const parts = blockSimilarities(a, b);
    const effective: BlockWeights = { ...defaultWeights(), ...weights };
    return { total: weightedSimilarity(parts, effective), parts };
  }
}
