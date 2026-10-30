import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CandidateFacts,
  DEFAULT_WEIGHTS,
  engagementRate,
  mergeWeights,
  orderStoryTray,
  rankFeed,
  scoreCandidate,
  seededRandom,
} from './feed-rank';

/** An ordinary post: a day old, a modest audience, nothing personal. */
const post = (over: Partial<CandidateFacts> = {}): CandidateFacts => ({
  id: over.id ?? Math.random().toString(36).slice(2),
  authorId: 'a',
  contentType: 'product_post',
  ageHours: 24,
  impressions: 200,
  uniqueViewers: 100,
  reactions: 5,
  replies: 1,
  saves: 1,
  shares: 0,
  productClicks: 2,
  orders: 0,
  watchTimeMs: 0,
  views: 100,
  hoursSinceEngagement: 20,
  reports: 0,
  authorQuality: 0.5,
  authorExposure: 1000,
  followsAuthor: false,
  authorAffinity: 0,
  interest: 0,
  servedCount: 0,
  alreadyEngaged: false,
  isOwn: false,
  ...over,
});

const W = DEFAULT_WEIGHTS.feed;
const score = (f: CandidateFacts) => scoreCandidate(f, W).score;
const noJitter = { jitter: 0, random: () => 0.5 };

test('a boutique she follows outranks a stranger of the same quality', () => {
  assert.ok(score(post({ followsAuthor: true })) > score(post()));
});

test('her history with an author and her categories both count', () => {
  assert.ok(score(post({ authorAffinity: 0.8 })) > score(post()));
  assert.ok(score(post({ interest: 0.9 })) > score(post()));
});

test('a fresh post beats a stale one — but a superb old one can beat a dull new one', () => {
  assert.ok(score(post({ ageHours: 2 })) > score(post({ ageHours: 96 })));
  const superbOld = post({ ageHours: 120, reactions: 300, saves: 80, shares: 40, uniqueViewers: 900, views: 900 });
  const dullNew = post({ ageHours: 1, reactions: 0, replies: 0, saves: 0, productClicks: 0, uniqueViewers: 300, views: 300 });
  assert.ok(score(superbOld) > score(dullNew));
});

test('three likes on three views is not better than three hundred on a thousand', () => {
  const tiny = post({ reactions: 3, replies: 0, saves: 0, productClicks: 0, uniqueViewers: 3, views: 3 });
  const big = post({ reactions: 300, replies: 0, saves: 0, productClicks: 0, uniqueViewers: 1000, views: 1000 });
  assert.ok(engagementRate(big) > engagementRate(tiny));
});

test('what she was already shown sinks, and what she already liked sinks further', () => {
  const fresh = score(post());
  const served = score(post({ servedCount: 1 }));
  const liked = score(post({ alreadyEngaged: true }));
  assert.ok(served < fresh * 0.5);
  assert.ok(liked < served);
});

test('reported content is not amplified while moderation decides', () => {
  assert.ok(score(post({ reports: 4 })) < score(post()) * 0.6);
});

test('the same author never appears twice in a row when there is an alternative', () => {
  const items = [
    post({ id: 'a1', authorId: 'a', followsAuthor: true, ageHours: 1 }),
    post({ id: 'a2', authorId: 'a', followsAuthor: true, ageHours: 2 }),
    post({ id: 'a3', authorId: 'a', followsAuthor: true, ageHours: 3 }),
    post({ id: 'b1', authorId: 'b' }),
    post({ id: 'c1', authorId: 'c' }),
  ];
  const order = rankFeed(items, { ...W, exploreEvery: 0 }, noJitter).map((r) => r.id);
  for (let i = 1; i < order.length - 1; i += 1) {
    const author = (id: string) => id[0];
    if (author(order[i]) === author(order[i - 1])) {
      assert.fail(`two from one author in a row: ${order.join(',')}`);
    }
  }
});

test('every eighth place goes to a good new voice she does not follow', () => {
  const followed = Array.from({ length: 12 }, (_, i) =>
    post({ id: `f${i}`, authorId: `f${i}`, followsAuthor: true, ageHours: 1 + i }),
  );
  const newcomer = post({ id: 'new', authorId: 'newcomer', ageHours: 10, authorExposure: 20, authorQuality: 0.6 });
  const ranked = rankFeed([...followed, newcomer], W, noJitter);
  assert.equal(ranked[7].id, 'new');
  assert.equal(ranked[7].reason, 'new_voice');
});

test('reasons say why: following, trending, for you', () => {
  assert.equal(scoreCandidate(post({ followsAuthor: true }), W).reason, 'following');
  assert.equal(scoreCandidate(post({ interest: 0.8 }), W).reason, 'for_you');
  const hot = post({ reactions: 120, replies: 30, saves: 20, shares: 15, uniqueViewers: 300, views: 300, hoursSinceEngagement: 0.5 });
  assert.equal(scoreCandidate(hot, W).reason, 'trending');
});

test('reels lean on watch time', () => {
  const R = DEFAULT_WEIGHTS.reels;
  const held = post({ contentType: 'reel', views: 100, watchTimeMs: 100 * 14_000 });
  const skipped = post({ contentType: 'reel', views: 100, watchTimeMs: 100 * 1_500 });
  assert.ok(scoreCandidate(held, R).score > scoreCandidate(skipped, R).score * 1.1);
});

test('her own new post leads her feed for a moment', () => {
  const own = post({ id: 'mine', isOwn: true, ageHours: 0.5, authorId: 'me' });
  const ranked = rankFeed([post({ followsAuthor: true, id: 'x', authorId: 'x' }), own], W, noJitter);
  assert.equal(ranked[0].id, 'mine');
});

test('a session is reproducible: the same seed, the same order', () => {
  const items = Array.from({ length: 20 }, (_, i) => post({ id: `p${i}`, authorId: `a${i % 5}`, ageHours: i * 3 }));
  const a = rankFeed(items, W, { random: seededRandom('s1') }).map((r) => r.id);
  const b = rankFeed(items, W, { random: seededRandom('s1') }).map((r) => r.id);
  assert.deepEqual(a, b);
});

test('console overrides take numbers only', () => {
  const w = mergeWeights('feed', { feed: { follow: 0.5, interest: 'x', halfLifeHours: -1 } });
  assert.equal(w.follow, 0.5);
  assert.equal(w.interest, W.interest);
  assert.equal(w.halfLifeHours, W.halfLifeHours);
});

test('stories: her own first, unseen before seen, closest people first', () => {
  const g = (authorId: string, over: Partial<Parameters<typeof orderStoryTray>[0][number]> = {}) => ({
    authorId,
    isOwn: false,
    allSeen: false,
    followsAuthor: false,
    affinity: 0,
    newestAgeHours: 5,
    ...over,
  });
  const order = orderStoryTray([
    g('seen-close', { allSeen: true, followsAuthor: true }),
    g('stranger'),
    g('me', { isOwn: true, allSeen: true }),
    g('followed', { followsAuthor: true }),
    g('loved', { affinity: 0.9 }),
  ]).map((x) => x.authorId);
  assert.deepEqual(order, ['me', 'followed', 'loved', 'stranger', 'seen-close']);
});

test('stories: a paid plan lifts a stranger, never above someone she follows', () => {
  const g = (authorId: string, over: Partial<Parameters<typeof orderStoryTray>[0][number]> = {}) => ({
    authorId,
    isOwn: false,
    allSeen: false,
    followsAuthor: false,
    affinity: 0,
    newestAgeHours: 5,
    ...over,
  });
  const order = orderStoryTray([
    g('free-shop', { newestAgeHours: 1 }),
    g('diamond-shop', { promoted: 1 }),
    g('followed', { followsAuthor: true, newestAgeHours: 20 }),
  ]).map((x) => x.authorId);
  assert.deepEqual(order, ['followed', 'diamond-shop', 'free-shop']);
});
