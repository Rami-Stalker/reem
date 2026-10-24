import assert from 'node:assert/strict';
import { randomInt, randomUUID } from 'node:crypto';
import test from 'node:test';
import {
  PrismaClient,
  PurchaseStage,
  RoomCandidateStatus,
  RoomDecisionStatus,
  RoomKind,
  RoomMemberRole,
  RoomStatus,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { ExchangeRateService } from '../pricing/exchange-rate.service';
import { PurchasePlanService } from './purchase-plan.service';
import { RoomAccessService } from './room-access.service';
import { RoomCollaborationService } from './room-collaboration.service';
import { RoomCompareService } from './room-compare.service';
import { RoomDecisionService } from './room-decision.service';
import { RoomEventService } from './room-event.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RoomNotifier } from './room-notifier.service';
import { RoomsService } from './rooms.service';

/**
 * Ohara Rooms against the real catalogue.
 *
 * The kernel tests prove the decision arithmetic. These prove the claims that
 * only the database can settle — and each one is a claim the brief made:
 *
 *   - a room is decisions, not a basket: candidates accumulate and nothing is
 *     bought until one is chosen;
 *   - a shared link makes an advisor, never a spender;
 *   - a surprise gift room refuses its own recipient;
 *   - a plan is drawn from what was decided, and reaches checkout **without
 *     touching the cart**.
 *
 * Every case runs inside a transaction that is rolled back.
 */
const prisma = new PrismaClient();

class Rollback extends Error {}
type Tx = Parameters<Parameters<typeof prisma.$transaction>[0]>[0];

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

test.after(() => prisma.$disconnect());

function dbTest(name: string, body: (world: World) => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    let failure: unknown;
    try {
      await prisma.$transaction(
        async (tx) => {
          try {
            await body(build(tx));
          } catch (error) {
            failure = error;
          }
          throw new Rollback();
        },
        { timeout: 60_000 },
      );
    } catch (error) {
      if (!(error instanceof Rollback)) throw error;
    }
    if (failure) throw failure;
  });
}

function asPrisma(tx: Tx): PrismaService {
  return new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: unknown) => {
          if (Array.isArray(fn)) return Promise.all(fn);
          return (fn as (inner: Tx) => unknown)(tx);
        };
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

interface World {
  db: PrismaService;
  rooms: RoomsService;
  access: RoomAccessService;
  decisions: RoomDecisionService;
  collab: RoomCollaborationService;
  plans: PurchasePlanService;
  compare: RoomCompareService;
  /** What the last checkout was handed. The spy that proves no cart is used. */
  captured: { lines: unknown[]; clearCart: boolean | undefined }[];
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  // Notifications are exercised by their own cases below; here the notifier is
  // real, so the coalescing runs on the same rows the assertions read.
  // Push is stubbed: this spec is about which rows the coalescing writes, and
  // a real transport here would only ever report "no provider configured".
  const notifier = new RoomNotifier(db, {
    pushExisting: async () => {},
  } as unknown as NotificationsService);
  const events = new RoomEventService(db, notifier);
  const access = new RoomAccessService(db);
  const rooms = new RoomsService(db, access, events);
  const decisions = new RoomDecisionService(db, access, events);
  const collab = new RoomCollaborationService(db, access, events);

  const captured: World['captured'] = [];
  // A stub rather than the real checkout: this spec is about how a plan reaches
  // the till, not about the till, which has 28 integration cases of its own.
  const checkout = {
    checkoutLines: async (
      _userId: string,
      _dto: unknown,
      lines: unknown[],
      options: { clearCart?: boolean } = {},
    ) => {
      captured.push({ lines, clearCart: options.clearCart });
      return { order: { id: null } };
    },
  } as never;

  const rates = new ExchangeRateService(db);

  const plans = new PurchasePlanService(db, access, events, checkout, rates);
  const compare = new RoomCompareService(db, access, rates);
  return { db, rooms, access, decisions, collab, plans, compare, captured };
}

/**
 * A customer of this test's own, created inside its transaction and rolled
 * back with it.
 *
 * It used to borrow any existing customer. The suites run in parallel, and
 * others create and delete short-lived customers, so a borrowed one could
 * vanish mid-test — surfacing as "No such account" or a room-member foreign
 * key failure in whichever case happened to pick it. `skip` is kept so the
 * call sites still read as "somebody other than her".
 */
async function someCustomer(db: PrismaService, _skip: string[] = []) {
  const tag = randomUUID().replace(/-/g, '').slice(0, 12);
  const user = await db.user.create({
    data: {
      name: 'Rooms Spec',
      phone: `+9639${String(randomInt(10_000_000, 100_000_000))}`,
      username: `rooms_spec_${tag}`,
      role: 'CUSTOMER',
    },
    select: { id: true },
  });
  return user.id;
}

async function liveOffer(db: PrismaService, skip: string[] = []) {
  const offer = await db.sellerOffer.findFirst({
    where: {
      isActive: true,
      status: 'ACTIVE',
      stock: { gt: 2 },
      id: { notIn: skip },
    },
    select: { id: true, productId: true },
  });
  assert.ok(offer, 'the seeded shop has no live offer');
  return offer;
}

// ── A room is decisions, not a basket ───────────────────────────────────

dbTest('candidates accumulate and nothing is bought until one is chosen', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة العرس' });

  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });

  const first = await liveOffer(world.db);
  const second = await liveOffer(world.db, [first.id]);
  await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: first.id,
  });
  await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: second.id,
  });

  const candidates = await world.db.roomCandidate.findMany({
    where: { decisionId: decision.id },
  });
  assert.equal(candidates.length, 2);
  assert.ok(
    candidates.every((c) => c.status === RoomCandidateStatus.CANDIDATE),
    'adding must never mean choosing',
  );

  // And a room with nothing decided cannot be bought from — the whole model,
  // enforced in one place.
  await assert.rejects(() => world.plans.draw(room.id, userId), /decisions open/);
});

dbTest('choosing one of two resolves the decision and leaves the other unbought', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });

  const first = await liveOffer(world.db);
  const second = await liveOffer(world.db, [first.id]);
  const chosen = await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: first.id,
  });
  await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: second.id,
  });

  await world.decisions.choose(room.id, userId, chosen.id);

  const after = await world.db.roomDecision.findUniqueOrThrow({
    where: { id: decision.id },
  });
  assert.equal(after.status, RoomDecisionStatus.RESOLVED);

  const plan = await world.plans.draw(room.id, userId);
  assert.equal(plan.plan.items.length, 1, 'only the chosen piece is in the plan');
  assert.equal(plan.plan.items[0].offerId, first.id);
});

dbTest('re-proposing the chosen piece does not un-choose it', async (world) => {
  // Enthusiasm must not undo a decision. Someone re-adding the dress the room
  // had already settled on used to reset that candidate to CANDIDATE while the
  // decision stayed RESOLVED — a resolved question with no answer, which
  // readiness reported as settled and blocked at the same time.
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
    pickCount: 1,
  });

  const offer = await liveOffer(world.db);
  const candidate = await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: offer.id,
  });
  await world.decisions.choose(room.id, userId, candidate.id);

  const again = await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: offer.id,
  });

  assert.equal(again.id, candidate.id, 'it is the same candidate, not a second');
  assert.equal(
    again.status,
    RoomCandidateStatus.CHOSEN,
    're-proposing must leave the choice standing',
  );

  const after = await world.db.roomDecision.findUniqueOrThrow({
    where: { id: decision.id },
  });
  assert.equal(after.status, RoomDecisionStatus.RESOLVED);

  const chosen = await world.db.roomCandidate.count({
    where: { decisionId: decision.id, status: RoomCandidateStatus.CHOSEN },
  });
  assert.equal(chosen, 1, 'a resolved decision still has its answer');
});

dbTest('a question that wants one answer refuses a second', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
    pickCount: 1,
  });

  const first = await liveOffer(world.db);
  const second = await liveOffer(world.db, [first.id]);
  const a = await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: first.id,
  });
  const b = await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: second.id,
  });

  await world.decisions.choose(room.id, userId, a.id);
  await assert.rejects(
    () => world.decisions.choose(room.id, userId, b.id),
    /already has its/,
  );
});

dbTest('deciding to buy nothing settles the room', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });

  const dress = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });
  const bag = await world.decisions.addDecision(room.id, userId, {
    title: 'حقيبة',
  });

  const offer = await liveOffer(world.db);
  const candidate = await world.decisions.addCandidate(room.id, userId, dress.id, {
    offerId: offer.id,
  });
  await world.decisions.choose(room.id, userId, candidate.id);

  // The bag is still open, so the room is not ready…
  await assert.rejects(() => world.plans.draw(room.id, userId), /decisions open/);

  // …until she decides against it, which is a real outcome rather than a
  // deletion that leaves no trace.
  await world.decisions.skipDecision(room.id, userId, bag.id, 'غالية');
  const plan = await world.plans.draw(room.id, userId);
  assert.equal(plan.plan.items.length, 1);
});

dbTest('a room opened for an occasion starts with that occasion’s questions', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, {
    title: 'عرس رهف',
    kind: RoomKind.OCCASION,
    occasion: 'wedding',
  });

  assert.ok(room.decisions.length > 0, 'a wedding room knows a wedding needs things');
  assert.ok(
    room.decisions.every((d) => d.isSuggested && !d.isRequired),
    'seeded questions are suggestions, never obligations',
  );

  // And because they are suggestions, one chosen answer is enough to buy.
  const offer = await liveOffer(world.db);
  const candidate = await world.decisions.addCandidate(
    room.id,
    userId,
    room.decisions[0].id,
    { offerId: offer.id },
  );
  await world.decisions.choose(room.id, userId, candidate.id);

  const plan = await world.plans.draw(room.id, userId);
  assert.equal(plan.plan.items.length, 1);
});

// ── Other people ────────────────────────────────────────────────────────

dbTest('a shared link makes an advisor, never a spender', async (world) => {
  const ownerId = await someCustomer(world.db);
  const friendId = await someCustomer(world.db, [ownerId]);

  const room = await world.rooms.create(ownerId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, ownerId, {
    title: 'الفستان',
  });
  const offer = await liveOffer(world.db);
  const candidate = await world.decisions.addCandidate(
    room.id,
    ownerId,
    decision.id,
    { offerId: offer.id },
  );

  const shared = await world.access.share(room.id, ownerId);
  const access = await world.access.joinByLink(shared.shareSlug!, friendId);
  assert.equal(access.role, RoomMemberRole.ADVISOR);

  // She may argue…
  await world.collab.vote(room.id, friendId, candidate.id, 1, 'حلو كتير');
  await world.collab.comment(room.id, friendId, {
    body: 'الكحلي أحلى',
    candidateId: candidate.id,
  });

  // …and she may not decide, nor buy.
  await assert.rejects(
    () => world.decisions.choose(room.id, friendId, candidate.id),
    /does not allow/,
  );
  await assert.rejects(
    () => world.plans.draw(room.id, friendId),
    /does not allow/,
  );
});

dbTest('following a link twice does not demote a co-shopper', async (world) => {
  const ownerId = await someCustomer(world.db);
  const sisterId = await someCustomer(world.db, [ownerId]);

  const room = await world.rooms.create(ownerId, { title: 'إطلالة' });
  await world.access.invite(room.id, ownerId, {
    userId: sisterId,
    role: RoomMemberRole.CO_SHOPPER,
  });

  const shared = await world.access.share(room.id, ownerId);
  const access = await world.access.joinByLink(shared.shareSlug!, sisterId);

  assert.equal(access.role, RoomMemberRole.CO_SHOPPER);
});

dbTest('a surprise gift room refuses its own recipient', async (world) => {
  const ownerId = await someCustomer(world.db);
  const recipientId = await someCustomer(world.db, [ownerId]);

  const room = await world.rooms.create(ownerId, {
    title: 'هدية لمها',
    kind: RoomKind.GIFT,
    recipientName: 'مها',
    recipientUserId: recipientId,
    isSurprise: true,
  });

  const shared = await world.access.share(room.id, ownerId);

  // The same 404 a stranger gets: "you may not join because this is your
  // surprise" is itself the spoiler.
  await assert.rejects(
    () => world.access.joinByLink(shared.shareSlug!, recipientId),
    /not found/i,
  );
  await assert.rejects(
    () =>
      world.access.invite(room.id, ownerId, {
        userId: recipientId,
      }),
    /not found/i,
  );
});

dbTest('votes advise and do not decide', async (world) => {
  const ownerId = await someCustomer(world.db);
  const friendId = await someCustomer(world.db, [ownerId]);

  const room = await world.rooms.create(ownerId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, ownerId, {
    title: 'الفستان',
  });

  const first = await liveOffer(world.db);
  const second = await liveOffer(world.db, [first.id]);
  const popular = await world.decisions.addCandidate(room.id, ownerId, decision.id, {
    offerId: first.id,
  });
  const hers = await world.decisions.addCandidate(room.id, ownerId, decision.id, {
    offerId: second.id,
  });

  await world.access.invite(room.id, ownerId, { userId: friendId });
  await world.collab.vote(room.id, friendId, popular.id, 1);
  await world.collab.vote(room.id, ownerId, popular.id, 1);

  // The room clearly prefers one, and she chooses the other. Nothing stops her.
  await world.decisions.choose(room.id, ownerId, hers.id);

  const plan = await world.plans.draw(room.id, ownerId);
  assert.equal(plan.plan.items[0].offerId, second.id);
});

dbTest('a vote is one per person and changing your mind replaces it', async (world) => {
  const ownerId = await someCustomer(world.db);
  const room = await world.rooms.create(ownerId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, ownerId, {
    title: 'الفستان',
  });
  const offer = await liveOffer(world.db);
  const candidate = await world.decisions.addCandidate(
    room.id,
    ownerId,
    decision.id,
    { offerId: offer.id },
  );

  await world.collab.vote(room.id, ownerId, candidate.id, 1);
  await world.collab.vote(room.id, ownerId, candidate.id, -1);

  const after = await world.db.roomCandidate.findUniqueOrThrow({
    where: { id: candidate.id },
  });
  assert.equal(after.votesUp, 0);
  assert.equal(after.votesDown, 1);
  assert.equal(after.voteScore, -1);

  // Zero withdraws the opinion entirely.
  await world.collab.vote(room.id, ownerId, candidate.id, 0);
  const withdrawn = await world.db.roomCandidate.findUniqueOrThrow({
    where: { id: candidate.id },
  });
  assert.equal(withdrawn.votesDown, 0);
  assert.equal(withdrawn.voteScore, 0);
});

dbTest('a comment attaches to exactly one thing', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });

  await assert.rejects(
    () => world.collab.comment(room.id, userId, { body: 'شو رأيكن؟' }),
    /exactly one/,
  );
  await assert.rejects(
    () =>
      world.collab.comment(room.id, userId, {
        body: 'شو رأيكن؟',
        decisionId: decision.id,
        candidateId: decision.id,
      }),
    /exactly one/,
  );

  const ok = await world.collab.comment(room.id, userId, {
    body: 'شو رأيكن؟',
    decisionId: decision.id,
  });
  assert.ok(ok.id);
});

// ── The plan ────────────────────────────────────────────────────────────

dbTest('a plan reaches checkout without touching the cart', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });
  const offer = await liveOffer(world.db);
  const candidate = await world.decisions.addCandidate(
    room.id,
    userId,
    decision.id,
    { offerId: offer.id },
  );
  await world.decisions.choose(room.id, userId, candidate.id);

  const cartBefore = await world.db.cartItem.count({ where: { userId } });
  const plan = await world.plans.draw(room.id, userId);
  await world.plans.checkoutPlan(plan.plan.id, userId, {
    payment_method: 'COD',
  } as never);

  // The claim, checked from both ends: checkout was handed the plan's lines…
  assert.equal(world.captured.length, 1);
  assert.equal(world.captured[0].lines.length, 1);
  assert.equal(
    world.captured[0].clearCart,
    false,
    'buying from a room must not empty her cart',
  );

  // …and no cart row was written or removed on the way.
  const cartAfter = await world.db.cartItem.count({ where: { userId } });
  assert.equal(cartAfter, cartBefore, 'a room never writes to the cart');
});

dbTest('staging leaves the later lines on the plan', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });

  const dress = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });
  const shoes = await world.decisions.addDecision(room.id, userId, {
    title: 'الحذاء',
  });

  const first = await liveOffer(world.db);
  const second = await liveOffer(world.db, [first.id]);
  const a = await world.decisions.addCandidate(room.id, userId, dress.id, {
    offerId: first.id,
  });
  const b = await world.decisions.addCandidate(room.id, userId, shoes.id, {
    offerId: second.id,
  });
  await world.decisions.choose(room.id, userId, a.id);
  await world.decisions.choose(room.id, userId, b.id);

  const drawn = await world.plans.draw(room.id, userId);
  assert.equal(drawn.plan.items.length, 2);

  // "The dress now, the shoes next month" — a cart cannot hold this at all.
  const later = drawn.plan.items[1];
  await world.plans.setStage(
    drawn.plan.id,
    userId,
    later.id,
    PurchaseStage.LATER,
  );

  await world.plans.checkoutPlan(drawn.plan.id, userId, {
    payment_method: 'COD',
  } as never);

  assert.equal(world.captured[0].lines.length, 1, 'only the NOW stage is bought');

  const remaining = await world.db.purchasePlanItem.findMany({
    where: { planId: drawn.plan.id },
  });
  assert.equal(remaining.length, 1, 'the later line survives the purchase');
  assert.equal(remaining[0].stage, PurchaseStage.LATER);

  const room2 = await world.db.room.findUniqueOrThrow({ where: { id: room.id } });
  assert.equal(
    room2.status,
    RoomStatus.READY,
    'a room with lines left is not finished',
  );
});

dbTest('drawing a plan again supersedes the old one rather than duplicating it', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });
  const offer = await liveOffer(world.db);
  const candidate = await world.decisions.addCandidate(
    room.id,
    userId,
    decision.id,
    { offerId: offer.id },
  );
  await world.decisions.choose(room.id, userId, candidate.id);

  const first = await world.plans.draw(room.id, userId);
  const second = await world.plans.draw(room.id, userId);

  assert.notEqual(first.plan.id, second.plan.id);
  assert.equal(second.plan.version, first.plan.version + 1);

  const live = await world.db.purchasePlan.count({
    where: { roomId: room.id, status: 'DRAFT' },
  });
  assert.equal(live, 1, 'only one plan is live at a time');
});

dbTest('the plan reports the budget without storing it', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, {
    title: 'إطلالة',
    budgetMaxSyp: 1,
  });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });
  const offer = await liveOffer(world.db);
  const candidate = await world.decisions.addCandidate(
    room.id,
    userId,
    decision.id,
    { offerId: offer.id },
  );
  await world.decisions.choose(room.id, userId, candidate.id);

  const plan = await world.plans.draw(room.id, userId);
  assert.equal(plan.budget.verdict, 'over');
  assert.ok(plan.budget.totalSyp > 0);

  // Nothing about money is on the row — it is computed on read.
  const row = await world.db.purchasePlan.findUniqueOrThrow({
    where: { id: plan.plan.id },
  });
  assert.ok(!('total' in row), 'a plan must not remember a price');
});

// ── The room’s memory ───────────────────────────────────────────────────

dbTest('a rejection keeps its reason', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });
  const offer = await liveOffer(world.db);
  const candidate = await world.decisions.addCandidate(
    room.id,
    userId,
    decision.id,
    { offerId: offer.id },
  );

  await world.decisions.reject(room.id, userId, candidate.id, 'قصير عليّ');

  const after = await world.db.roomCandidate.findUniqueOrThrow({
    where: { id: candidate.id },
  });
  assert.equal(after.status, RoomCandidateStatus.REJECTED);
  assert.equal(after.rejectionNote, 'قصير عليّ');
});

dbTest('proposing a rejected piece again reopens it rather than duplicating', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });
  const offer = await liveOffer(world.db);

  const first = await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: offer.id,
  });
  await world.decisions.reject(room.id, userId, first.id, 'غالي');
  const again = await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: offer.id,
  });

  assert.equal(again.id, first.id, 'the same piece is the same candidacy');
  assert.equal(again.status, RoomCandidateStatus.CANDIDATE);
  assert.equal(again.rejectionNote, null);

  const count = await world.db.roomCandidate.count({
    where: { decisionId: decision.id },
  });
  assert.equal(count, 1);
});

dbTest('the room keeps a timeline of what happened in it', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });
  const offer = await liveOffer(world.db);
  const candidate = await world.decisions.addCandidate(
    room.id,
    userId,
    decision.id,
    { offerId: offer.id },
  );
  await world.decisions.choose(room.id, userId, candidate.id);

  const events = await world.db.roomEvent.findMany({
    where: { roomId: room.id },
    orderBy: { createdAt: 'asc' },
  });

  const kinds = events.map((event) => event.kind);
  assert.ok(kinds.includes('ROOM_CREATED'));
  assert.ok(kinds.includes('DECISION_ADDED'));
  assert.ok(kinds.includes('CANDIDATE_ADDED'));
  assert.ok(kinds.includes('DECISION_RESOLVED'));
});

dbTest('a room is invisible to somebody who is not in it', async (world) => {
  const ownerId = await someCustomer(world.db);
  const strangerId = await someCustomer(world.db, [ownerId]);

  const room = await world.rooms.create(ownerId, { title: 'إطلالة' });

  // 404, not 403: a room's existence is itself private.
  await assert.rejects(
    () => world.rooms.detail(room.id, strangerId),
    /not found/i,
  );
});

// ── Telling the room ────────────────────────────────────────────────────

dbTest('an afternoon of votes is one notification, not thirty', async (world) => {
  const ownerId = await someCustomer(world.db);
  const friendId = await someCustomer(world.db, [ownerId]);

  const room = await world.rooms.create(ownerId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, ownerId, {
    title: 'الفستان',
  });
  await world.access.invite(room.id, ownerId, { userId: friendId });

  const first = await liveOffer(world.db);
  const second = await liveOffer(world.db, [first.id]);
  const a = await world.decisions.addCandidate(room.id, ownerId, decision.id, {
    offerId: first.id,
  });
  const b = await world.decisions.addCandidate(room.id, ownerId, decision.id, {
    offerId: second.id,
  });

  const before = await world.db.notification.count({
    where: { userId: ownerId, type: 'room' },
  });

  // Her friend votes several times in one sitting.
  await world.collab.vote(room.id, friendId, a.id, 1);
  await world.collab.vote(room.id, friendId, b.id, -1);
  await world.collab.vote(room.id, friendId, a.id, -1);
  await world.collab.comment(room.id, friendId, {
    body: 'الكحلي أحلى',
    candidateId: a.id,
  });

  const notices = await world.db.notification.findMany({
    where: { userId: ownerId, type: 'room' },
    orderBy: { createdAt: 'desc' },
  });

  assert.equal(
    notices.length - before,
    1,
    'a room folds its activity into one line',
  );
  const payload = notices[0].data as Record<string, unknown>;
  assert.equal(payload['room_id'], room.id);
  assert.ok(
    Number(payload['count']) >= 4,
    'and the line counts what it folded',
  );
});

dbTest('nobody is told about her own gesture', async (world) => {
  const ownerId = await someCustomer(world.db);
  const room = await world.rooms.create(ownerId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, ownerId, {
    title: 'الفستان',
  });
  const offer = await liveOffer(world.db);
  const candidate = await world.decisions.addCandidate(
    room.id,
    ownerId,
    decision.id,
    { offerId: offer.id },
  );
  await world.collab.vote(room.id, ownerId, candidate.id, 1);

  const mine = await world.db.notification.count({
    where: { userId: ownerId, type: 'room', data: { path: ['room_id'], equals: room.id } },
  });
  assert.equal(mine, 0, 'a woman alone in a room hears nothing');
});

dbTest('a decision being resolved gets its own line', async (world) => {
  const ownerId = await someCustomer(world.db);
  const friendId = await someCustomer(world.db, [ownerId]);

  const room = await world.rooms.create(ownerId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, ownerId, {
    title: 'الفستان',
  });
  await world.access.invite(room.id, ownerId, { userId: friendId });

  const offer = await liveOffer(world.db);
  const candidate = await world.decisions.addCandidate(
    room.id,
    ownerId,
    decision.id,
    { offerId: offer.id },
  );

  // Chatter first, so there is an open line to fold into…
  await world.collab.comment(room.id, ownerId, {
    body: 'شو رأيك؟',
    candidateId: candidate.id,
  });
  // …then the room actually moves.
  await world.decisions.choose(room.id, ownerId, candidate.id);

  const notices = await world.db.notification.findMany({
    where: {
      userId: friendId,
      type: 'room',
      data: { path: ['room_id'], equals: room.id },
    },
  });

  assert.equal(
    notices.length,
    2,
    'chatter folds; a decision is an event and stands alone',
  );
  assert.ok(
    notices.some((notice) =>
      (notice.data as Record<string, unknown>)['kind'] === 'DECISION_RESOLVED',
    ),
  );
});

dbTest('somebody who muted rooms is not told', async (world) => {
  const ownerId = await someCustomer(world.db);
  const friendId = await someCustomer(world.db, [ownerId]);

  const room = await world.rooms.create(ownerId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, ownerId, {
    title: 'الفستان',
  });
  await world.access.invite(room.id, ownerId, { userId: friendId });

  await world.db.notificationPreference.upsert({
    where: { userId: friendId },
    create: { userId: friendId, inAppRooms: false },
    update: { inAppRooms: false },
  });

  const offer = await liveOffer(world.db);
  await world.decisions.addCandidate(room.id, ownerId, decision.id, {
    offerId: offer.id,
  });

  const notices = await world.db.notification.count({
    where: {
      userId: friendId,
      type: 'room',
      data: { path: ['room_id'], equals: room.id },
    },
  });
  assert.equal(notices, 0);
});

dbTest('the recipient of a surprise is never told about it', async (world) => {
  const ownerId = await someCustomer(world.db);
  const recipientId = await someCustomer(world.db, [ownerId]);
  const friendId = await someCustomer(world.db, [ownerId, recipientId]);

  const room = await world.rooms.create(ownerId, {
    title: 'هدية',
    kind: RoomKind.GIFT,
    recipientName: 'مها',
    recipientUserId: recipientId,
    isSurprise: true,
  });
  const decision = await world.decisions.addDecision(room.id, ownerId, {
    title: 'الهدية',
  });
  await world.access.invite(room.id, ownerId, { userId: friendId });

  const offer = await liveOffer(world.db);
  await world.decisions.addCandidate(room.id, ownerId, decision.id, {
    offerId: offer.id,
  });

  const leaked = await world.db.notification.count({
    where: {
      userId: recipientId,
      data: { path: ['room_id'], equals: room.id },
    },
  });
  assert.equal(leaked, 0, 'a notification is the one thing that leaves the room');

  // And the friend who is actually in it does hear.
  const heard = await world.db.notification.count({
    where: {
      userId: friendId,
      type: 'room',
      data: { path: ['room_id'], equals: room.id },
    },
  });
  assert.ok(heard > 0);
});

// ── Comparing ───────────────────────────────────────────────────────────

dbTest('a comparison marks what differs and collapses what does not', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });

  const first = await liveOffer(world.db);
  const second = await liveOffer(world.db, [first.id]);
  await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: first.id,
  });
  await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: second.id,
  });

  const comparison = await world.compare.compare(room.id, userId, decision.id);

  assert.equal(comparison.candidateIds.length, 2);
  assert.ok(comparison.rows.length > 0);

  // Every row carries a cell for every candidate — a comparison with a hole in
  // it is worse than none.
  for (const row of comparison.rows) {
    for (const id of comparison.candidateIds) {
      assert.ok(row.values[id], `row ${row.key} is missing ${id}`);
    }
  }

  // And the differing rows come first.
  const firstNonDiffering = comparison.rows.findIndex((row) => !row.differs);
  if (firstNonDiffering !== -1) {
    assert.ok(
      comparison.rows.slice(firstNonDiffering).every((row) => !row.differs),
      'rows they agree on sink to the bottom together',
    );
  }
});

dbTest('the cheapest is marked, in SYP rather than in numerals', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });

  const first = await liveOffer(world.db);
  const second = await liveOffer(world.db, [first.id]);
  await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: first.id,
  });
  await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: second.id,
  });

  const comparison = await world.compare.compare(room.id, userId, decision.id);
  const price = comparison.rows.find((row) => row.key === 'price');
  assert.ok(price);

  if (price.differs) {
    const winners = Object.values(price.values).filter((cell) => cell.best);
    assert.ok(winners.length >= 1, 'a differing price row names its cheapest');

    // The winner is the lowest SYP figure, whatever currency it displays in.
    const lowest = Math.min(
      ...Object.values(price.values)
        .map((cell) => cell.raw)
        .filter((raw): raw is number => typeof raw === 'number'),
    );
    for (const cell of Object.values(price.values)) {
      if (cell.best) assert.equal(cell.raw, lowest);
    }
  }
});

dbTest('a rejected candidate is out of the comparison', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });

  const first = await liveOffer(world.db);
  const second = await liveOffer(world.db, [first.id]);
  const a = await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: first.id,
  });
  await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: second.id,
  });

  await world.decisions.reject(room.id, userId, a.id, 'قصير');
  const comparison = await world.compare.compare(room.id, userId, decision.id);

  assert.ok(
    !comparison.candidateIds.includes(a.id),
    're-presenting a ruled-out option is re-arguing a settled point',
  );
});

dbTest('one candidate has nothing to compare against', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });
  const offer = await liveOffer(world.db);
  await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: offer.id,
  });

  const comparison = await world.compare.compare(room.id, userId, decision.id);
  assert.deepEqual(comparison.rows, []);
  assert.equal(comparison.verdict.code, 'IDENTICAL');
});

dbTest('the comparison can be narrowed to a shortlist', async (world) => {
  const userId = await someCustomer(world.db);
  const room = await world.rooms.create(userId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, userId, {
    title: 'الفستان',
  });

  const first = await liveOffer(world.db);
  const second = await liveOffer(world.db, [first.id]);
  const third = await liveOffer(world.db, [first.id, second.id]);
  const a = await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: first.id,
  });
  const b = await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: second.id,
  });
  await world.decisions.addCandidate(room.id, userId, decision.id, {
    offerId: third.id,
  });

  const comparison = await world.compare.compare(room.id, userId, decision.id, [
    a.id,
    b.id,
  ]);
  assert.deepEqual(comparison.candidateIds.sort(), [a.id, b.id].sort());
});

dbTest('a stranger cannot read a room’s comparison', async (world) => {
  const ownerId = await someCustomer(world.db);
  const strangerId = await someCustomer(world.db, [ownerId]);

  const room = await world.rooms.create(ownerId, { title: 'إطلالة' });
  const decision = await world.decisions.addDecision(room.id, ownerId, {
    title: 'الفستان',
  });

  await assert.rejects(
    () => world.compare.compare(room.id, strangerId, decision.id),
    /not found/i,
  );
});
