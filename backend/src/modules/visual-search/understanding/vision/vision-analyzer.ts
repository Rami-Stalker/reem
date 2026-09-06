/** DI token for the vision provider, when one is configured. */
export const VISION_ANALYZER = Symbol('VISION_ANALYZER');

/** The engine name recorded when no model looked at the picture. */
export const PIXELS_ENGINE = 'reem-visual-pixels-v1';

export interface VisionAnalysisInput {
  /** The re-encoded, EXIF-stripped copy. Never the file as she sent it. */
  image: Buffer;
  mimeType: string;
  /**
   * What the descriptor already measured, offered as a starting point the way
   * the stylist offers its rule reading. A model that agrees costs nothing; a
   * model that disagrees about a colour loses, because the pixels are not an
   * opinion.
   */
  measured: {
    colours: string[];
    pattern: string;
    framing: string;
  };
  /** The leaf category slugs that exist, so a proposal can be checked. */
  knownCategorySlugs: readonly string[];
}

export interface VisionAnalysis {
  /**
   * A proposed `Partial<StyleBrief>`, unvalidated. The caller runs
   * `sanitiseBrief` over it — the same gate the stylist's text extractor
   * passes through — so a model naming a colour or a category that does not
   * exist proposes nothing rather than something wrong.
   */
  brief: unknown;

  /**
   * Proposed garments in the frame, shaped
   * `[{ slot, label, box: { x, y, w, h }, confidence }]` in normalised
   * coordinates. Validated by `sanitiseDetections` before use.
   */
  items: unknown;
}

/**
 * The seam a vision model plugs into — and, as with `StylistLlm`, the shape of
 * the hole it is allowed to fill.
 *
 * One operation, and it *proposes*. It does not search, does not score, does
 * not rank and does not see the catalogue beyond a list of category slugs it
 * may choose from. Everything it returns is run through the stylist's existing
 * sanitiser before any of it reaches a query.
 *
 * There is deliberately no "which products match this photograph" operation.
 * That question is answered by comparing vectors against rows, and a model
 * allowed to answer it is a model allowed to describe a dress nobody sells.
 */
export interface VisionAnalyzer {
  /** Recorded in `visual_search_sessions.engine`. */
  readonly name: string;

  /** False when nothing is configured — the pixels path then stands alone. */
  readonly enabled: boolean;

  /**
   * Returns proposals, or null when the model is unavailable, slow, or
   * returned something unusable. Never throws: a visual search that fails
   * because a third party is down is a worse product than one that describes a
   * photograph slightly less richly.
   */
  analyse(input: VisionAnalysisInput): Promise<VisionAnalysis | null>;
}

/**
 * The no-op implementation, and the default.
 *
 * A real provider rather than a null check at each call site, so the
 * measurement path is the thing under test rather than a branch beside it —
 * and so the feature is complete with no key configured. With this in place
 * visual search still works end to end: the descriptor finds the matches, the
 * pixels name the colours, and the catalogue neighbours name the category.
 * What is missing is only the vocabulary a model would add — "قصّة حورية"
 * for a silhouette, a handbag picked out of the corner of a frame.
 */
export class DisabledVisionAnalyzer implements VisionAnalyzer {
  readonly name = PIXELS_ENGINE;
  readonly enabled = false;

  async analyse(): Promise<null> {
    return null;
  }
}
