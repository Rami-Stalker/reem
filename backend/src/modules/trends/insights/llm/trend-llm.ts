import { TrendInsightKind, TrendInsightSeverity } from '@prisma/client';

/**
 * The seam a language model plugs into — and the shape of the hole it is
 * allowed to fill.
 *
 * There is exactly one operation, and it takes a finished finding and returns
 * prose. That is the entire contract, and it is the reason a model can be
 * pointed at a business-intelligence system without the numbers becoming
 * unreliable:
 *
 *  - **It cannot decide what is interesting.** Which findings exist is decided
 *    by `insight-rules.ts` from pre-computed scores. The model is handed the
 *    ones that already fired.
 *  - **It cannot compute anything.** Every figure it may quote is in
 *    `metrics`, already rounded, already correct. It is told to use those and
 *    only those, and the caller checks the result before storing it.
 *  - **It cannot fail loudly.** Every path returns null on timeout, transport
 *    error, non-200 or an unusable shape, and the caller then uses the Arabic
 *    template — which is a complete implementation, not a stub.
 *
 * The worst outcome of a bad model, a bad prompt or a bad day at the provider
 * is therefore a duller sentence attached to the same correct number. There is
 * deliberately no `whatIsTrending`, no `analyse`, no `explainWhy`: the moment a
 * model is asked to *produce* a fact rather than phrase one, every figure on
 * every dashboard becomes something nobody can check.
 */
export interface TrendLlm {
  /** Recorded in `trend_insights.narrator`. */
  readonly name: string;

  /** False when nothing is configured — the caller skips straight to Arabic. */
  readonly enabled: boolean;

  /**
   * Phrase a batch of findings.
   *
   * Batched rather than one-at-a-time because a nightly run produces dozens
   * and a request each would be slow, expensive, and — the real problem —
   * would let the run half-fail into a dashboard where some rows are warm
   * prose and others are templates.
   *
   * Returns a map from `dedupeKey` to the phrasing. A key the model omitted,
   * or returned nonsense for, simply keeps its template.
   */
  phrase(
    findings: readonly PhrasingRequest[],
  ): Promise<Map<string, PhrasedInsight>>;
}

export interface PhrasingRequest {
  /** Correlates the answer back to the finding. Never shown to the reader. */
  dedupeKey: string;
  kind: TrendInsightKind;
  severity: TrendInsightSeverity;
  /** The product title, category name or colour the finding is about. */
  subjectLabel: string;
  /** The only numbers the model is permitted to use. */
  metrics: Record<string, number | string | boolean | null>;
  /** The template's output, offered as the reference phrasing. */
  fallback: { titleAr: string; bodyAr: string; actionAr: string | null };
  /** SELLER copy is addressed to her; ADMIN copy is a market briefing. */
  audience: 'SELLER' | 'ADMIN';
}

export interface PhrasedInsight {
  titleAr: string;
  bodyAr: string;
  actionAr: string | null;
}

export const TREND_LLM = Symbol('TREND_LLM');

/**
 * The default, and a real implementation rather than a null check at each
 * call site — so the deterministic path is the thing under test rather than a
 * branch beside it.
 */
export class DisabledTrendLlm implements TrendLlm {
  readonly name = 'reem-trend-templates-v1';
  readonly enabled = false;

  async phrase(): Promise<Map<string, PhrasedInsight>> {
    return new Map();
  }
}
