import { Inject, Injectable, Logger } from '@nestjs/common';
import { CacheService } from '../../../common/cache/cache.service';
import { PrismaService } from '../../../prisma/prisma.service';
import {
  StyleBrief,
  emptyBrief,
  mergeBriefs,
  sanitiseBrief,
} from '../../ai-stylist/understanding/style-brief';
import { Embedding } from '../embedding/embedding.service';
import { PreparedImage } from '../processing/image-processing.service';
import {
  DetectedRegion,
  sanitiseDetections,
  segmentLayout,
  wholeFrameRegion,
} from '../regions/region-segmenter';
import {
  VisualAttributes,
  readingsToAttributes,
} from './visual-attributes';
import { PIXELS_ENGINE, VISION_ANALYZER, VisionAnalyzer } from './vision/vision-analyzer';

export interface ImageUnderstanding {
  attributes: VisualAttributes;
  /** What the picture says, as a brief the stylist's machinery understands. */
  brief: StyleBrief;
  regions: DetectedRegion[];
  /** `reem-visual-pixels-v1`, or the model id when one was consulted. */
  engine: string;
}

/**
 * Reading a photograph.
 *
 * Three sources are folded here, and the order they are folded in *is* the
 * policy:
 *
 *   1. **The pixels.** Always. Colours, pattern, tone, framing — measured, not
 *      inferred, and the same numbers every time.
 *   2. **The vision model**, when one is configured. It proposes; the pixels
 *      already measured what they measured, and a model contradicting a
 *      measurement loses on the fields the measurement covers. What it adds is
 *      the vocabulary pixels do not have: which garment this is, what
 *      occasion it reads as, where the handbag is in the frame.
 *   3. **The catalogue neighbours**, folded in later by the search service
 *      once there are neighbours to fold — see `withNeighbourCategories`. That
 *      step is deliberately downstream: it needs a search to have happened.
 *
 * Every proposal from step 2 goes through `sanitiseBrief` — the *same*
 * function the stylist's text extractor uses, against the *same* closed
 * vocabularies. A vision model cannot name a colour this shop does not stock
 * any more than a language model can.
 */
@Injectable()
export class VisualUnderstandingService {
  private readonly logger = new Logger(VisualUnderstandingService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: CacheService,
    @Inject(VISION_ANALYZER) private readonly vision: VisionAnalyzer,
  ) {}

  async understand(
    prepared: PreparedImage,
    embedding: Embedding,
  ): Promise<ImageUnderstanding> {
    const attributes = embedding.readings
      ? readingsToAttributes(embedding.readings)
      : emptyAttributes();

    // The measured half, expressed as a brief. Colours only: the pixels have
    // nothing honest to say about category, budget or size, and a brief that
    // claimed otherwise would filter the search on a guess.
    let brief = mergeBriefs(emptyBrief(), {
      colours: attributes.colours.map((colour) => colour.key),
      confidence: attributes.confidence,
    });

    let regions = this.layoutRegions(prepared, attributes);
    let engine = PIXELS_ENGINE;

    if (this.vision.enabled) {
      const slugs = await this.knownCategorySlugs();
      const analysis = await this.vision.analyse({
        image: prepared.buffer,
        mimeType: 'image/webp',
        measured: {
          colours: attributes.colours.map((colour) => colour.key),
          pattern: attributes.pattern,
          framing: attributes.framing,
        },
        knownCategorySlugs: slugs,
      });

      if (analysis) {
        engine = this.vision.name;

        const proposed = sanitiseBrief(analysis.brief, {
          knownCategorySlugs: new Set(slugs),
        });
        // The measured colours are the base and the model's are folded on top
        // — `mergeBriefs` unions colour sets, so a model that agrees changes
        // nothing and one that spots a second colour adds it. It cannot
        // *replace* what the pixels measured.
        brief = mergeBriefs(brief, proposed);

        const detections = sanitiseDetections(analysis.items);
        if (detections.length) regions = detections;

        if (proposed.categorySlugs?.length || proposed.slots?.length) {
          attributes.categories = await this.labelCategories(brief.categorySlugs);
          attributes.slots = brief.slots;
          attributes.provenance.categories = 'VISION';
          attributes.provenance.slots = 'VISION';
        }
      }
    }

    return { attributes, brief, regions, engine };
  }

  /**
   * Folds one typed sentence onto an existing reading.
   *
   * This is the whole of natural-language refinement, and it is three lines
   * because the stylist already owns the hard part: `BriefExtractorService`
   * turns "أريد شي مشابه وأقل من ٤٠٠ ألف" into a partial brief, and
   * `mergeBriefs` knows that a restated budget replaces while an added colour
   * accumulates. Visual search does not get its own parser, its own vocabulary
   * or its own merge rules — that is how two features drift into disagreeing
   * about what "محتشم" means.
   */
  refine(current: StyleBrief, extracted: Partial<StyleBrief>): StyleBrief {
    return mergeBriefs(current, extracted);
  }

  private layoutRegions(
    prepared: PreparedImage,
    attributes: VisualAttributes,
  ): DetectedRegion[] {
    if (!prepared.frame) return [wholeFrameRegion(attributes)];

    try {
      const bands = segmentLayout(prepared.frame, attributes);
      return bands.length ? bands : [wholeFrameRegion(attributes)];
    } catch (error) {
      // Segmentation is an enhancement over searching the whole frame. A bug
      // in the band walk must degrade to the simple answer, not to an error
      // page on a woman who uploaded a photograph.
      this.logger.warn(`Layout segmentation failed: ${String(error)}`);
      return [wholeFrameRegion(attributes)];
    }
  }

  /**
   * The Arabic names for a set of slugs.
   *
   * A slug is an identifier and never belongs on screen: the chip row read
   * "الأقرب: abayas" in an otherwise entirely Arabic surface because the
   * payload carried nothing else. Cached with the vocabulary it comes from.
   */
  async labelCategories(
    slugs: readonly string[],
  ): Promise<Array<{ slug: string; label: string }>> {
    if (!slugs.length) return [];

    const rows = await this.prisma.category.findMany({
      where: { slug: { in: [...slugs] } },
      select: { slug: true, nameAr: true },
    });
    const names = new Map(rows.map((row) => [row.slug, row.nameAr]));

    // Order follows the caller's, which is the order of confidence.
    return slugs.map((slug) => ({ slug, label: names.get(slug) ?? slug }));
  }

  /**
   * Every leaf category slug, cached.
   *
   * Read from the database rather than hard-coded so the vocabulary a model is
   * offered and the vocabulary `sanitiseBrief` validates against are the same
   * list, and an admin adding a category does not have to remember this file.
   */
  async knownCategorySlugs(): Promise<string[]> {
    return this.cache.wrap('visual:category-slugs', 10 * 60 * 1000, async () => {
      const rows = await this.prisma.category.findMany({
        where: { level: 2 },
        select: { slug: true },
        orderBy: { slug: 'asc' },
      });
      return rows.map((row) => row.slug);
    });
  }
}

/**
 * The reading of an image whose embedder produced no interpretable signals — a
 * hosted model returning a bare vector.
 *
 * Everything is absent rather than defaulted. The search still works: the
 * vector is the part that finds things, and the categories arrive from the
 * neighbours a moment later.
 */
function emptyAttributes(): VisualAttributes {
  return {
    colours: [],
    pattern: 'plain',
    tone: 'mid',
    framing: 'product',
    studioBackground: false,
    subjectFill: 0,
    categories: [],
    slots: [],
    provenance: {},
    confidence: 0,
  };
}
