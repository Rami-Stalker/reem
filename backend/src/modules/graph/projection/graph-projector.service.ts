import { Injectable, Logger } from '@nestjs/common';
import { GraphEdge, GraphNode, Prisma } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import {
  EDGE_FLOOR,
  PROJECTION_WINDOW_DAYS,
  nodeId,
} from '../graph.constants';
import { edgeWeight } from '../kernel/graph-math';

/**
 * Filling the graph from the tables that already hold the truth.
 *
 * Every edge written here is derived from a row somewhere else — a favourite,
 * an order line, a closet item, a room candidate, a search roll-up. Nothing is
 * invented and nothing is stored that could not be rebuilt by running this
 * again over the same data.
 *
 * ── Why a projector and not event hooks ──────────────────────────────────
 *
 * The same choice Ohara Value made, for the same reason. Hooks mean every
 * feature that touches a favourite has to remember to tell the graph, and the
 * day somebody forgets, the graph is quietly wrong in a way nothing detects.
 * A projector that reads the source tables cannot drift: if the favourite is
 * there, the edge is there, and if the projection has a bug the fix is one
 * re-run rather than a backfill script.
 *
 * ── The one thing it must never do ───────────────────────────────────────
 *
 * Write an edge for something that did not happen. Every method below is a
 * query with a `where` that names real rows, and the weights come from the
 * kernel rather than from anything invented at the call site.
 */
@Injectable()
export class GraphProjectorService {
  private readonly logger = new Logger(GraphProjectorService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Rebuild one woman's edges.
   *
   * Scoped to a user because that is the unit everything reads: the product
   * page asks about *her*, and a full-population sweep is only ever this run
   * in a loop.
   */
  async projectUser(
    userId: string,
    options: { now?: Date } = {},
  ): Promise<{ edges: number }> {
    const now = options.now ?? new Date();
    const since = new Date(now.getTime() - PROJECTION_WINDOW_DAYS * 86_400_000);

    const drafts: EdgeDraft[] = [
      ...(await this.owned(userId, now)),
      ...(await this.purchased(userId, since, now)),
      ...(await this.saved(userId, since, now)),
      ...(await this.considered(userId, since, now)),
      ...(await this.needed(userId, now)),
      ...(await this.shopsFor(userId, now)),
      ...(await this.searched(userId, since, now)),
    ];

    await this.write(userId, drafts);
    return { edges: drafts.length };
  }

  // ── Sources ────────────────────────────────────────────────────────────

  /**
   * Her closet. The strongest edges in the graph.
   *
   * Both the product (when the piece came from Ohara) and the slot, because
   * "she owns four dresses" is a fact about slots that no product edge
   * expresses.
   */
  private async owned(userId: string, now: Date): Promise<EdgeDraft[]> {
    const items = await this.prisma.closetItem.findMany({
      where: { userId, status: 'ACTIVE' },
      select: {
        id: true,
        productId: true,
        slot: true,
        colours: true,
        acquiredAt: true,
        createdAt: true,
      },
    });

    const drafts: EdgeDraft[] = [];
    const slotCounts = new Map<string, { n: number; newest: Date }>();

    for (const item of items) {
      const at = item.acquiredAt ?? item.createdAt;
      if (item.productId) {
        drafts.push({
          objectType: GraphNode.PRODUCT,
          objectId: item.productId,
          kind: GraphEdge.OWNS,
          at,
          evidence: { closetItemId: item.id, colours: item.colours },
        });
      }
      const slot = slotCounts.get(item.slot);
      if (!slot || at > slot.newest) {
        slotCounts.set(item.slot, {
          n: (slot?.n ?? 0) + 1,
          newest: slot ? (at > slot.newest ? at : slot.newest) : at,
        });
      } else {
        slot.n += 1;
      }
    }

    for (const [slot, info] of slotCounts) {
      drafts.push({
        objectType: GraphNode.SLOT,
        objectId: nodeId(GraphNode.SLOT, slot),
        kind: GraphEdge.OWNS,
        at: info.newest,
        observations: info.n,
        // The key travels in evidence because the id is a hash — see
        // `KEYED_NODES` in the constants.
        evidence: { slot, count: info.n },
      });
    }

    void now;
    return drafts;
  }

  /** What she bought, and who she bought it from. */
  private async purchased(
    userId: string,
    since: Date,
    now: Date,
  ): Promise<EdgeDraft[]> {
    const lines = await this.prisma.orderItem.findMany({
      where: {
        // An order line hangs off a *sub*-order, which is what carries the
        // seller; the buyer is one hop further up.
        sellerOrder: { order: { userId, createdAt: { gte: since } } },
        productId: { not: null },
      },
      select: {
        productId: true,
        sellerOrder: {
          select: {
            sellerId: true,
            order: { select: { id: true, createdAt: true } },
          },
        },
      },
    });

    const drafts: EdgeDraft[] = [];
    const sellers = new Map<string, { n: number; newest: Date }>();

    for (const line of lines) {
      const placedAt = line.sellerOrder.order.createdAt;
      if (line.productId) {
        drafts.push({
          objectType: GraphNode.PRODUCT,
          objectId: line.productId,
          kind: GraphEdge.PURCHASED,
          at: placedAt,
          evidence: { orderId: line.sellerOrder.order.id },
        });
      }
      const sellerId = line.sellerOrder.sellerId;
      if (sellerId) {
        const seen = sellers.get(sellerId);
        sellers.set(sellerId, {
          n: (seen?.n ?? 0) + 1,
          newest: seen && seen.newest > placedAt ? seen.newest : placedAt,
        });
      }
    }

    for (const [sellerId, info] of sellers) {
      drafts.push({
        objectType: GraphNode.SELLER,
        objectId: sellerId,
        kind: GraphEdge.BUYS_FROM,
        at: info.newest,
        observations: info.n,
        evidence: { orders: info.n },
      });
    }

    void now;
    return drafts;
  }

  /** Favourites. */
  private async saved(
    userId: string,
    since: Date,
    now: Date,
  ): Promise<EdgeDraft[]> {
    const rows = await this.prisma.favorite.findMany({
      where: { userId, createdAt: { gte: since } },
      select: { productId: true, createdAt: true },
    });
    void now;
    return rows.map((row) => ({
      objectType: GraphNode.PRODUCT,
      objectId: row.productId,
      kind: GraphEdge.SAVED,
      at: row.createdAt,
      evidence: {},
    }));
  }

  /**
   * Pieces she put in a room — weighed, not bought.
   *
   * A rejected candidate is deliberately excluded: she looked at it and said
   * no, and treating that as interest is how a recommender starts insisting on
   * the one thing its user has already refused.
   */
  private async considered(
    userId: string,
    since: Date,
    now: Date,
  ): Promise<EdgeDraft[]> {
    const rows = await this.prisma.roomCandidate.findMany({
      where: {
        decision: { room: { ownerId: userId } },
        status: { not: 'REJECTED' },
        createdAt: { gte: since },
      },
      select: { productId: true, createdAt: true, decisionId: true },
    });
    void now;
    return rows.map((row) => ({
        objectType: GraphNode.PRODUCT,
        objectId: row.productId,
      kind: GraphEdge.CONSIDERED,
      at: row.createdAt,
      evidence: { decisionId: row.decisionId },
    }));
  }

  /**
   * Slots she is short of — from open closet gaps and unresolved room
   * decisions.
   *
   * The most actionable edge in the graph: it is the difference between
   * knowing what she likes and knowing what she is missing.
   */
  private async needed(userId: string, now: Date): Promise<EdgeDraft[]> {
    const [gaps, decisions] = await Promise.all([
      this.prisma.closetGap.findMany({
        where: { closet: { userId }, status: 'OPEN' },
        select: { slot: true, computedAt: true, occasion: true },
      }),
      this.prisma.roomDecision.findMany({
        where: {
          room: { ownerId: userId },
          status: 'OPEN',
          slot: { not: null },
        },
        select: { slot: true, createdAt: true, room: { select: { occasion: true } } },
      }),
    ]);

    const drafts: EdgeDraft[] = [];
    for (const gap of gaps) {
      drafts.push({
        objectType: GraphNode.SLOT,
        objectId: nodeId(GraphNode.SLOT, gap.slot),
        kind: GraphEdge.NEEDS,
        at: gap.computedAt ?? now,
        evidence: { slot: gap.slot, from: 'closet_gap', occasion: gap.occasion },
      });
    }
    for (const decision of decisions) {
      if (!decision.slot) continue;
      drafts.push({
        objectType: GraphNode.SLOT,
        objectId: nodeId(GraphNode.SLOT, decision.slot),
        kind: GraphEdge.NEEDS,
        at: decision.createdAt,
        evidence: {
          slot: decision.slot,
          from: 'room_decision',
          occasion: decision.room.occasion,
        },
      });
    }
    return drafts;
  }

  /** Occasions she is shopping for, from her looks and her rooms. */
  private async shopsFor(userId: string, now: Date): Promise<EdgeDraft[]> {
    const [looks, rooms] = await Promise.all([
      this.prisma.closetLook.findMany({
        where: { userId, isArchived: false, occasion: { not: null } },
        select: { occasion: true, updatedAt: true },
      }),
      this.prisma.room.findMany({
        where: { ownerId: userId, occasion: { not: null } },
        select: { occasion: true, lastActivityAt: true },
      }),
    ]);

    const counts = new Map<string, { n: number; newest: Date }>();
    const note = (key: string | null, at: Date) => {
      if (!key) return;
      const seen = counts.get(key);
      counts.set(key, {
        n: (seen?.n ?? 0) + 1,
        newest: seen && seen.newest > at ? seen.newest : at,
      });
    };

    for (const look of looks) note(look.occasion, look.updatedAt);
    for (const room of rooms) note(room.occasion, room.lastActivityAt);

    void now;
    return [...counts.entries()].map(([occasion, info]) => ({
      objectType: GraphNode.OCCASION,
      objectId: nodeId(GraphNode.OCCASION, occasion),
      kind: GraphEdge.SHOPS_FOR,
      at: info.newest,
      observations: info.n,
      evidence: { occasion, count: info.n },
    }));
  }

  /**
   * What she searched for.
   *
   * Read from `AnalyticsEvent` rather than `SearchTermDaily`, because the
   * daily roll-up is deliberately anonymised — it says how many people asked
   * for a term, never who. The raw event carries the user and is retained only
   * briefly, which is exactly the right lifetime for an edge that decays in a
   * month anyway.
   */
  private async searched(
    userId: string,
    since: Date,
    now: Date,
  ): Promise<EdgeDraft[]> {
    const rows = await this.prisma.analyticsEvent.findMany({
      where: {
        userId,
        type: { in: ['PRODUCT_SEARCH', 'SEARCH_RESULT_CLICK'] },
        createdAt: { gte: since },
      },
      select: { metadata: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
      take: 300,
    });

    const counts = new Map<string, { n: number; newest: Date; display: string }>();
    for (const row of rows) {
      const meta = (row.metadata ?? {}) as Record<string, unknown>;
      const key = typeof meta['termKey'] === 'string' ? meta['termKey'] : null;
      if (!key) continue;
      const display = typeof meta['query'] === 'string' ? meta['query'] : key;
      const seen = counts.get(key);
      counts.set(key, {
        n: (seen?.n ?? 0) + 1,
        newest: seen && seen.newest > row.createdAt ? seen.newest : row.createdAt,
        display: seen?.display ?? display,
      });
    }

    void now;
    return [...counts.entries()].map(([key, info]) => ({
      objectType: GraphNode.TERM,
      objectId: nodeId(GraphNode.TERM, key),
      kind: GraphEdge.SEARCHED,
      at: info.newest,
      observations: info.n,
      evidence: { term: key, display: info.display, count: info.n },
    }));
  }

  // ── Writing ────────────────────────────────────────────────────────────

  /**
   * Collapse the drafts and write them.
   *
   * Drafts arrive one per source row, so the same product can appear several
   * times with the same kind — three orders of the same dress, say. They are
   * folded first so `observations` means what it says, then written with the
   * weight the kernel computes from the freshest occurrence.
   */
  private async write(userId: string, drafts: EdgeDraft[]): Promise<void> {
    const folded = new Map<string, Folded>();

    for (const draft of drafts) {
      const key = `${draft.objectType}:${draft.objectId}:${draft.kind}`;
      const seen = folded.get(key);
      if (seen) {
        seen.observations += draft.observations ?? 1;
        if (draft.at > seen.newest) seen.newest = draft.at;
        if (draft.at < seen.oldest) seen.oldest = draft.at;
      } else {
        folded.set(key, {
          objectType: draft.objectType,
          objectId: draft.objectId,
          kind: draft.kind,
          observations: draft.observations ?? 1,
          newest: draft.at,
          oldest: draft.at,
          evidence: draft.evidence,
        });
      }
    }

    const now = Date.now();
    const kept: string[] = [];

    for (const edge of folded.values()) {
      const ageDays = Math.max(
        0,
        (now - edge.newest.getTime()) / 86_400_000,
      );
      const weight = edgeWeight({
        kind: edge.kind,
        observations: edge.observations,
        ageDays,
      });
      // Below the floor an edge is not worth a row — it would only slow every
      // read that ever joins this table.
      if (weight < EDGE_FLOOR) continue;

      const where = {
        subjectType_subjectId_objectType_objectId_kind: {
          subjectType: GraphNode.USER,
          subjectId: userId,
          objectType: edge.objectType,
          objectId: edge.objectId,
          kind: edge.kind,
        },
      };

      await this.prisma.commerceEdge.upsert({
        where,
        create: {
          subjectType: GraphNode.USER,
          subjectId: userId,
          objectType: edge.objectType,
          objectId: edge.objectId,
          kind: edge.kind,
          weight,
          observations: edge.observations,
          evidence: edge.evidence as Prisma.InputJsonValue,
          firstSeenAt: edge.oldest,
          lastSeenAt: edge.newest,
        },
        // Weight is *replaced*, never incremented: it is a function of the
        // behaviour and its age, so recomputing is the only way it can fall
        // when the behaviour stops.
        update: {
          weight,
          observations: edge.observations,
          evidence: edge.evidence as Prisma.InputJsonValue,
          lastSeenAt: edge.newest,
        },
      });

      kept.push(`${edge.objectType}:${edge.objectId}:${edge.kind}`);
    }

    // Anything she used to have an edge to and no longer does — an unfavourited
    // product, a closed gap — is removed rather than left to decay. A stale
    // edge would keep answering questions with something that is no longer
    // true.
    const existing = await this.prisma.commerceEdge.findMany({
      where: { subjectType: GraphNode.USER, subjectId: userId },
      select: { id: true, objectType: true, objectId: true, kind: true },
    });
    const keptSet = new Set(kept);
    const stale = existing
      .filter((e) => !keptSet.has(`${e.objectType}:${e.objectId}:${e.kind}`))
      .map((e) => e.id);

    if (stale.length) {
      await this.prisma.commerceEdge.deleteMany({ where: { id: { in: stale } } });
    }
  }

  /**
   * Rebuild the whole population.
   *
   * Only users who have done something the graph can see, so a table of
   * registered accounts does not become a table of empty projections.
   */
  async projectAll(options: { now?: Date } = {}): Promise<{
    users: number;
    edges: number;
    failed: number;
  }> {
    const users = await this.prisma.user.findMany({
      where: {
        OR: [
          { closet: { isNot: null } },
          { favorites: { some: {} } },
          { orders: { some: {} } },
          { roomsOwned: { some: {} } },
        ],
      },
      select: { id: true },
    });

    let edges = 0;
    let failed = 0;
    for (const user of users) {
      try {
        edges += (await this.projectUser(user.id, options)).edges;
      } catch (error) {
        failed += 1;
        this.logger.warn(`Graph projection failed for ${user.id}: ${String(error)}`);
      }
    }

    this.logger.log(
      `Commerce graph: ${users.length} shoppers, ${edges} edges, ${failed} failed`,
    );
    return { users: users.length, edges, failed };
  }
}

interface EdgeDraft {
  objectType: GraphNode;
  objectId: string;
  kind: GraphEdge;
  at: Date;
  observations?: number;
  evidence: Record<string, unknown>;
}

interface Folded {
  objectType: GraphNode;
  objectId: string;
  kind: GraphEdge;
  observations: number;
  newest: Date;
  oldest: Date;
  evidence: Record<string, unknown>;
}
