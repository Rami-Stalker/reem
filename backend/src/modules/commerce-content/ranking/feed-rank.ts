/**
 * How the community feed and the reels are ordered for one woman.
 *
 * Pure, like every kernel in this codebase: plain facts in, a score and an
 * order out, so any position on her screen can be re-derived by hand from the
 * rows behind it. The service gathers the facts; nothing here reads a
 * database or asks a model.
 *
 * ## The shape of a score
 *
 *     score = relevance × quality × freshness × (not already shown)
 *
 * **Relevance** is a weighted sum of things that are evidence she will care:
 * she follows the author; she has liked, saved, commented on or bought from
 * this author before; the piece is in the categories she shops; it is good
 * (its engagement rate, smoothed so three likes on three views does not beat
 * three hundred on a thousand); it is moving right now; and the author is a
 * boutique customers trust. Every component is 0–1, so the weights read as
 * shares of the decision.
 *
 * **Freshness** halves on a half-life but never reaches zero, so a superb
 * post from last week can still beat a dull one from this morning.
 *
 * **Quality** — the smoothed engagement rate — also scales the whole score
 * (0.6× to 1.4×), so evidence that a piece is good can outlast its age.
 *
 * **Already shown** is the difference between a feed and a loop. A piece she
 * was served and scrolled past drops sharply; one she already liked drops
 * further — she has seen it, and said so.
 *
 * Then the list is **diversified** — never the same author twice in a row,
 * at most three of one author in any ten — and every eighth place goes to a
 * **new voice**: a good, fresh piece from somebody she does not follow and
 * whom few have seen yet. Without that, a feed only ever shows her what she
 * already knows and a new boutique can never be discovered.
 */

const clamp01 = (n: number) => Math.max(0, Math.min(1, n));
const saturate = (x: number, k: number) => 1 - Math.exp(-Math.max(0, x) / k);
const halfLife = (age: number, life: number) =>
  life <= 0 ? 1 : Math.pow(0.5, Math.max(0, age) / life);

export type FeedKind = 'feed' | 'reels';

/** Why a piece is where it is — the client shows the non-obvious ones. */
export type RankReason = 'following' | 'for_you' | 'trending' | 'new_voice' | 'popular';

export interface CandidateFacts {
  id: string;
  authorId: string;
  /** `product_post`, `reel` … */
  contentType: string;
  ageHours: number;

  // The piece's own record.
  impressions: number;
  uniqueViewers: number;
  reactions: number;
  replies: number;
  saves: number;
  shares: number;
  productClicks: number;
  orders: number;
  watchTimeMs: number;
  views: number;
  /** Hours since anybody last engaged with it; null when nobody has. */
  hoursSinceEngagement: number | null;
  reports: number;

  // The author.
  /** 0–1: the boutique's standing (rank score), or a neutral 0.5. */
  authorQuality: number;
  /** How many times the platform has shown this author lately, to anyone. */
  authorExposure: number;

  // This viewer and this piece.
  followsAuthor: boolean;
  /** 0–1: her history with this author — likes, saves, comments, purchases. */
  authorAffinity: number;
  /** 0–1: how much the piece's categories are hers. */
  interest: number;
  /** Times it was already served to her recently. */
  servedCount: number;
  /** She already liked or saved it. */
  alreadyEngaged: boolean;
  isOwn: boolean;
}

export interface RankWeights {
  follow: number;
  affinity: number;
  interest: number;
  engagement: number;
  momentum: number;
  commerce: number;
  quality: number;
  watch: number;
  base: number;
  /** Freshness half-life, hours. */
  halfLifeHours: number;
  /** The share of a score freshness can never take away. */
  freshnessFloor: number;
  /** Every Nth place is offered to a new voice. 0 turns it off. */
  exploreEvery: number;
}

export const DEFAULT_WEIGHTS: Readonly<Record<FeedKind, RankWeights>> = {
  feed: {
    follow: 0.3,
    affinity: 0.18,
    interest: 0.16,
    engagement: 0.14,
    momentum: 0.08,
    commerce: 0.05,
    quality: 0.06,
    watch: 0,
    base: 0.03,
    halfLifeHours: 30,
    freshnessFloor: 0.15,
    exploreEvery: 8,
  },
  // Reels are watched, not scrolled past: what holds attention matters more
  // than who posted it, and discovery is most of the point.
  reels: {
    follow: 0.14,
    affinity: 0.12,
    interest: 0.16,
    engagement: 0.16,
    momentum: 0.1,
    commerce: 0.04,
    quality: 0.04,
    watch: 0.2,
    base: 0.04,
    halfLifeHours: 72,
    freshnessFloor: 0.2,
    exploreEvery: 4,
  },
};

/** System setting: `{ "feed": { "follow": 0.35, … }, "reels": { … } }`. */
export const RANK_WEIGHTS_SETTING = 'feed.ranking_weights';

/** Overrides from the console, numbers only, everything else ignored. */
export function mergeWeights(kind: FeedKind, raw: unknown): RankWeights {
  const base = { ...DEFAULT_WEIGHTS[kind] };
  const section =
    raw && typeof raw === 'object' ? (raw as Record<string, unknown>)[kind] : null;
  if (section && typeof section === 'object') {
    for (const key of Object.keys(base) as (keyof RankWeights)[]) {
      const value = (section as Record<string, unknown>)[key];
      if (typeof value === 'number' && Number.isFinite(value) && value >= 0) {
        base[key] = value;
      }
    }
  }
  return base;
}

/** Engagement needed before a rate is believed — a prior of this many views. */
const PRIOR_VIEWS = 40;
const PRIOR_RATE = 0.04;

/**
 * Engagement per view, shrunk towards the platform's ordinary rate until
 * there is traffic to believe. Comments, saves and shares count for more than
 * a like: each costs her more than a tap.
 */
export function engagementRate(f: CandidateFacts): number {
  const weighted =
    f.reactions + 2 * f.replies + 3 * f.saves + 3 * f.shares + 2 * f.productClicks;
  const audience = Math.max(f.uniqueViewers, f.views, f.impressions * 0.3);
  const rate = (weighted + PRIOR_RATE * PRIOR_VIEWS) / (audience + PRIOR_VIEWS);
  return saturate(rate, 0.12);
}

/** Engagement still arriving: recent, and of some size. */
export function momentum(f: CandidateFacts): number {
  if (f.hoursSinceEngagement === null) return 0;
  const volume = saturate(f.reactions + f.replies * 2 + f.saves * 2 + f.shares * 3, 25);
  return halfLife(f.hoursSinceEngagement, 10) * volume;
}

/** It sells: product taps and orders per view. */
export function commerce(f: CandidateFacts): number {
  const audience = Math.max(f.uniqueViewers, f.views, 1);
  return saturate((f.productClicks + 5 * f.orders) / (audience + 20), 0.08);
}

/** For a reel: the average watch, against a dozen seconds. */
export function watchQuality(f: CandidateFacts): number {
  if (f.views <= 0) return 0.3;
  return saturate(f.watchTimeMs / f.views, 12_000);
}

export interface Scored {
  facts: CandidateFacts;
  score: number;
  reason: RankReason;
  /** Eligible for a new-voice slot. */
  explorable: boolean;
}

export function scoreCandidate(f: CandidateFacts, w: RankWeights): Scored {
  const eng = engagementRate(f);
  const mom = momentum(f);
  const relevance =
    w.follow * (f.followsAuthor ? 1 : 0) +
    w.affinity * clamp01(f.authorAffinity) +
    w.interest * clamp01(f.interest) +
    w.engagement * eng +
    w.momentum * mom +
    w.commerce * commerce(f) +
    w.quality * clamp01(f.authorQuality) +
    w.watch * watchQuality(f) +
    w.base;

  const fresh = w.freshnessFloor + (1 - w.freshnessFloor) * halfLife(f.ageHours, w.halfLifeHours);

  // Shown before: once costs a lot, twice more; liked or saved already, more.
  let seen = 1;
  if (f.alreadyEngaged) seen = 0.2;
  else if (f.servedCount > 0) seen = Math.pow(0.45, Math.min(3, f.servedCount));

  // Reports are a doubt, not a verdict — moderation decides; ranking only
  // stops amplifying while it does.
  const doubt = 1 / (1 + 0.25 * Math.max(0, f.reports));

  // Her own new post leads her feed for a moment, so she sees it went up;
  // after that it should not crowd out everybody else's.
  const own = f.isOwn ? (f.ageHours < 2 ? 3 : 0.3) : 1;

  // How good the piece is lifts or sinks everything else: a followed
  // boutique's post that nobody engages with should not lead her feed, and
  // a post hundreds loved should survive a few days of age.
  const lift = 0.6 + 0.8 * eng;

  const score = relevance * lift * fresh * seen * doubt * own;

  const reason: RankReason = f.followsAuthor
    ? 'following'
    : mom > 0.55 && eng > 0.45
      ? 'trending'
      : f.interest >= 0.5 || f.authorAffinity >= 0.35
        ? 'for_you'
        : 'popular';

  const explorable =
    !f.followsAuthor &&
    !f.isOwn &&
    f.servedCount === 0 &&
    f.ageHours < 72 &&
    f.authorExposure < 400 &&
    f.authorQuality >= 0.35 &&
    f.reports === 0;

  return { facts: f, score, reason, explorable };
}

/**
 * The order she sees.
 *
 * Greedy: at each place take the best remaining piece after the penalties
 * for repeating an author, and every `exploreEvery`th place offer to the best
 * new voice first. `random` gives a little jitter (±`jitter`) so the feed is
 * alive between refreshes without being arbitrary; the service seeds it per
 * session, so one session's pages agree with each other.
 */
export function rankFeed(
  candidates: readonly CandidateFacts[],
  weights: RankWeights,
  options: { random?: () => number; jitter?: number; limit?: number } = {},
): { id: string; reason: RankReason; score: number }[] {
  const random = options.random ?? Math.random;
  const jitter = options.jitter ?? 0.08;
  const limit = options.limit ?? candidates.length;

  const pool = candidates.map((c) => {
    const s = scoreCandidate(c, weights);
    return { ...s, score: s.score * (1 + jitter * (random() - 0.5) * 2) };
  });

  const out: { id: string; reason: RankReason; score: number }[] = [];
  const recentAuthors: string[] = [];
  const used = new Set<string>();

  const adjusted = (item: (typeof pool)[number]) => {
    const author = item.facts.authorId;
    let penalty = 1;
    if (recentAuthors[recentAuthors.length - 1] === author) penalty *= 0.25;
    const inWindow = recentAuthors.slice(-10).filter((a) => a === author).length;
    if (inWindow >= 3) penalty *= 0.05;
    else if (inWindow > 0) penalty *= Math.pow(0.7, inWindow);
    return item.score * penalty;
  };

  while (out.length < limit && used.size < pool.length) {
    const place = out.length + 1;
    const exploreHere = weights.exploreEvery > 0 && place % weights.exploreEvery === 0;

    let best: (typeof pool)[number] | null = null;
    let bestScore = -Infinity;
    if (exploreHere) {
      for (const item of pool) {
        if (used.has(item.facts.id) || !item.explorable) continue;
        const s = adjusted(item);
        if (s > bestScore) [best, bestScore] = [item, s];
      }
    }
    if (!best) {
      for (const item of pool) {
        if (used.has(item.facts.id)) continue;
        const s = adjusted(item);
        if (s > bestScore) [best, bestScore] = [item, s];
      }
    }
    if (!best) break;

    used.add(best.facts.id);
    recentAuthors.push(best.facts.authorId);
    out.push({
      id: best.facts.id,
      reason: exploreHere && best.explorable ? 'new_voice' : best.reason,
      score: Number(best.score.toFixed(6)),
    });
  }
  return out;
}

/**
 * A small deterministic generator, so a session's jitter is reproducible:
 * the same seed gives the same feed, and the next session a fresh one.
 */
export function seededRandom(seed: string): () => number {
  let h = 2166136261;
  for (let i = 0; i < seed.length; i += 1) {
    h ^= seed.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  let state = h >>> 0 || 1;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return ((state >>> 0) % 1_000_000) / 1_000_000;
  };
}

// ── Stories ──────────────────────────────────────────────────────────────

export interface StoryGroupFacts {
  authorId: string;
  isOwn: boolean;
  allSeen: boolean;
  followsAuthor: boolean;
  /** 0–1, as for the feed. */
  affinity: number;
  /** Hours since her newest live story. */
  newestAgeHours: number;
  /**
   * 0–1: the boutique's paid plan. Lifts a ring among the shops she does not
   * follow yet — never above one she does.
   */
  promoted?: number;
}

/**
 * The tray: her own ring first; then every ring with something unseen,
 * closest people first; then the rings she has finished. Within a band,
 * closeness (following, then her history with the author) leads and
 * recency breaks ties — the order a woman would open them herself. Among
 * the shops she does not follow, a paid plan moves a ring forward.
 */
export function orderStoryTray<T extends StoryGroupFacts>(groups: readonly T[]): T[] {
  const closeness = (g: T) =>
    (g.followsAuthor ? 0.6 : 0.25 * clamp01(g.promoted ?? 0)) +
    0.4 * clamp01(g.affinity) +
    0.2 * halfLife(g.newestAgeHours, 8);
  return [...groups].sort((a, b) => {
    if (a.isOwn !== b.isOwn) return a.isOwn ? -1 : 1;
    if (a.allSeen !== b.allSeen) return a.allSeen ? 1 : -1;
    const diff = closeness(b) - closeness(a);
    if (Math.abs(diff) > 1e-9) return diff;
    return a.newestAgeHours - b.newestAgeHours;
  });
}
