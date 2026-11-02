import { StyleBrief } from '../understanding/style-brief';

/**
 * The seam a language model plugs into — and, more importantly, the shape of
 * the hole it is allowed to fill.
 *
 * Two operations, both optional, both narrow:
 *
 *  - `extractBrief` reads a sentence and *proposes* values from closed
 *    vocabularies. Its output is passed through `sanitiseBrief` before anything
 *    else sees it, so the worst a confused model can do is propose nothing.
 *  - `composeReply` phrases a sentence around products that have **already**
 *    been chosen from the database. It is handed the facts and returns prose;
 *    it cannot add, remove or reprice a single card.
 *
 * There is deliberately no third operation. "Ask the model what to recommend"
 * is the design this interface exists to make unavailable: it is how an
 * assistant ends up confidently describing a dress that nobody sells.
 */
export interface StylistLlm {
  /** Identifies the engine in `ai_stylist_messages.engine`. */
  readonly name: string;

  /** False when nothing is configured — callers skip straight to the rules. */
  readonly enabled: boolean;

  /**
   * Returns a partial brief, or null when the model is unavailable, slow, or
   * returned something unusable. Never throws: a stylist that fails because a
   * third party is down is a worse product than one that reads a sentence a
   * little less cleverly.
   */
  extractBrief(input: BriefExtractionInput): Promise<unknown | null>;

  /** Returns the reply sentence, or null to fall back to the templates. */
  composeReply(input: ReplyCompositionInput): Promise<string | null>;
}

export interface BriefExtractionInput {
  /** This turn, as she typed it. */
  message: string;
  /** The last few turns, oldest first, for pronoun and follow-up resolution. */
  history: Array<{ role: 'user' | 'assistant'; content: string }>;
  /** What the conversation already established. */
  currentBrief: StyleBrief;
  /** What the rules layer read on its own, offered as a starting point. */
  ruleBrief: Partial<StyleBrief>;
}

export interface ReplyCompositionInput {
  /**
   * What the reply is about. `advice` is an opinion question with no cards
   * under it — the one mode where the model writes styling knowledge rather
   * than presenting a selection, and still may not name a product.
   */
  mode: 'products' | 'outfit' | 'advice';
  message: string;
  /** The last few turns, oldest first, so the reply follows the thread. */
  history: Array<{ role: 'user' | 'assistant'; content: string }>;
  /** The deterministic styling answer, offered as a starting point. */
  advice: string | null;
  brief: StyleBrief;
  /**
   * The real rows, already selected and already priced. The prompt states that
   * these are the only products that exist.
   */
  products: Array<{
    title: string;
    priceLabel: string;
    sellerName: string;
    reason: string;
    inStock: boolean;
  }>;
  /** Constraints that had to be loosened to find anything, in plain Arabic. */
  relaxations: string[];
  /** The follow-up question the deterministic path would have asked. */
  followUp: string | null;
  outfitTitle: string | null;
}

export const STYLIST_LLM = Symbol('STYLIST_LLM');

/** The engine name recorded when no model was involved. */
export const RULES_ENGINE = 'reem-stylist-rules-v1';

/**
 * The no-op implementation, and the default.
 *
 * It is a real provider rather than a null check at each call site so the
 * conversation service has exactly one code path, and so the deterministic
 * behaviour is the thing under test rather than a branch beside it.
 */
export class DisabledStylistLlm implements StylistLlm {
  readonly name = RULES_ENGINE;
  readonly enabled = false;

  async extractBrief(): Promise<null> {
    return null;
  }

  async composeReply(): Promise<null> {
    return null;
  }
}
