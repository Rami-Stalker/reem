import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  DropAudience,
  DropStatus,
  GraphEdge,
  GraphNode,
  MarketSubject,
  OfferStatus,
  Prisma,
  ProductStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { detectOccasion, detectSlots } from '../../ai-stylist/understanding/stylist-lexicon';
import { MarketEconomicsService } from '../economics/market-economics.service';
import {
  CandidateSignals,
  DropShape,
  Invitation,
  measureDrop,
  selectAudience,
} from '../kernel/drop-audience';
import { launchPotential } from '../kernel/economics';

/**
 * Running a launch.
 *
 * Three jobs, and the middle one is the feature. Choosing *what* to launch
 * reads the economics layer; choosing *who* reads the commerce graph;
 * measuring what happened reads the invitations. Take any of the three away
 * and a drop is a scheduled sale with a countdown on it.
 *
 * ── What this deliberately does not do ───────────────────────────────────
 *
 * Discount anything. A drop is an *event*, not a promotion: the products are
 * sold at their own prices through the offers that already exist, and the only
 * thing the drop changes is who sees them and when. Building price mechanics
 * in here would turn the feature into a coupon engine, which Reem has already
 * decided twice it does not want.
 */
@Injectable()
export class DropsService {
  private readonly logger = new Logger(DropsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly economics: MarketEconomicsService,
  ) {}

  // ── What to launch ─────────────────────────────────────────────────────

  /**
   * Products worth making an event of, for one seller or for the platform.
   *
   * Read straight from the market signals — the judgement about launch
   * potential was already made by the kernel, and remaking it here would be a
   * second opinion nobody asked for.
   */
  async candidates(options: { sellerId?: string; limit?: number } = {}) {
    const rows = await this.economics.launchCandidates(120);
    const limit = options.limit ?? 12;

    const scored = rows
      .filter((row) =>
        options.sellerId
          ? row.product.offers.some((o) => o.sellerId === options.sellerId)
          : true,
      )
      .map((row) => {
        const findings = (row.signal.findings ?? []) as Array<{
          code: string;
          strength: number;
        }>;
        const stock = row.product.offers.reduce((t, o) => t + o.stock, 0);
        const ageDays =
          (Date.now() - row.product.createdAt.getTime()) / 86_400_000;

        const potential = launchPotential({
          reading: {
            demandScore: row.signal.demandScore,
            supplyScore: row.signal.supplyScore,
            conversionScore: row.signal.conversionScore,
            competition: row.signal.competition,
            tension: row.signal.tension,
            priceIndexBps: row.signal.priceIndexBps,
            confidence: row.signal.confidence,
            findings: findings as never,
            components: {},
          },
          ageDays,
          stockUnits: stock,
        });

        return {
          productId: row.product.id,
          title: row.product.title,
          potential,
          demandScore: row.signal.demandScore,
          tension: row.signal.tension,
          stockUnits: stock,
          ageDays: Math.round(ageDays),
          findings: findings.map((f) => f.code),
        };
      })
      .filter((row) => row.potential > 0)
      .sort((a, b) => b.potential - a.potential)
      .slice(0, limit);

    return scored;
  }

  // ── Creating one ───────────────────────────────────────────────────────

  async create(
    input: {
      sellerId: string | null;
      title: string;
      note?: string | null;
      audience: DropAudience;
      startsAt: Date;
      earlyAccessAt?: Date | null;
      endsAt?: Date | null;
      productIds: string[];
    },
  ) {
    if (!input.productIds.length) {
      throw new BadRequestException('A drop needs at least one product');
    }
    if (input.endsAt && input.endsAt <= input.startsAt) {
      throw new BadRequestException('A drop cannot end before it starts');
    }
    if (input.earlyAccessAt && input.earlyAccessAt > input.startsAt) {
      throw new BadRequestException(
        'Early access cannot begin after the drop opens',
      );
    }

    // A seller may only launch what she actually sells. Enforced by the query
    // rather than by a check somebody could forget.
    const products = await this.prisma.product.findMany({
      where: {
        id: { in: input.productIds },
        status: ProductStatus.ACTIVE,
        offers: {
          some: {
            status: OfferStatus.ACTIVE,
            ...(input.sellerId ? { sellerId: input.sellerId } : {}),
          },
        },
      },
      select: { id: true },
    });
    if (products.length !== input.productIds.length) {
      throw new BadRequestException(
        'Every product in a drop must be live and yours to sell',
      );
    }

    const signals = await this.prisma.marketSignal.findMany({
      where: {
        subjectType: MarketSubject.PRODUCT,
        subjectId: { in: input.productIds },
      },
      orderBy: { day: 'desc' },
    });

    return this.prisma.drop.create({
      data: {
        sellerId: input.sellerId,
        title: input.title.trim(),
        note: input.note ?? null,
        audience: input.audience,
        // A draft, not a schedule. Creating a drop and committing to send it
        // are two decisions, and collapsing them means a seller who wanted to
        // see how large the audience would be has already announced it. The
        // order is: draft, target, look at who it reached, then schedule.
        status: DropStatus.DRAFT,
        startsAt: input.startsAt,
        earlyAccessAt: input.earlyAccessAt ?? null,
        endsAt: input.endsAt ?? null,
        rationale: {
          generatedAt: new Date().toISOString(),
          signals: input.productIds.map((id) => {
            const signal = signals.find((s) => s.subjectId === id);
            return {
              productId: id,
              demandScore: signal?.demandScore ?? null,
              tension: signal?.tension ?? null,
            };
          }),
        } as Prisma.InputJsonValue,
        products: {
          create: input.productIds.map((id, index) => ({
            productId: id,
            position: index,
            reason: (signals.find((s) => s.subjectId === id)?.findings ??
              []) as Prisma.InputJsonValue,
          })),
        },
      },
      include: {
        products: {
          orderBy: { position: 'asc' },
          include: {
            product: {
              select: {
                id: true,
                title: true,
                minPriceSyp: true,
                media: {
                  take: 1,
                  orderBy: { sortOrder: 'asc' },
                  select: { url: true, blurHash: true },
                },
              },
            },
          },
        },
      },
    });
  }

  // ── Who it is for ──────────────────────────────────────────────────────

  /**
   * Build the audience from the commerce graph.
   *
   * Idempotent: re-running replaces the invitation list rather than adding to
   * it, so a drop cannot accumulate a stale audience across several attempts
   * at targeting it.
   */
  async buildAudience(
    dropId: string,
    options: { limit?: number; sellerId?: string } = {},
  ): Promise<{ invited: number; shape: DropShape }> {
    // A seller may only target her own drop. Checked here rather than in the
    // controller because targeting is the step that sends notifications.
    await this.requireOwned(dropId, options.sellerId);

    const drop = await this.prisma.drop.findUniqueOrThrow({
      where: { id: dropId },
      include: {
        products: {
          include: {
            product: {
              select: {
                id: true,
                title: true,
                description: true,
                offers: {
                  where: { status: OfferStatus.ACTIVE },
                  select: { sellerId: true },
                },
              },
            },
          },
        },
      },
    });

    const shape = this.shapeOf(drop.products.map((p) => p.product));
    const candidates = await this.candidateSignals(
      drop.products.map((p) => p.productId),
      shape,
    );
    const invitations = selectAudience(shape, candidates, {
      limit: options.limit ?? 300,
    });

    await this.prisma.$transaction(async (tx) => {
      // Replace rather than append — see the note on idempotency above.
      // Invitations already notified are kept, because un-sending is not a
      // thing and the measurement would lose its denominator.
      await tx.dropInvite.deleteMany({
        where: { dropId, notifiedAt: null },
      });

      for (const invite of invitations) {
        await tx.dropInvite.upsert({
          where: { dropId_userId: { dropId, userId: invite.userId } },
          create: {
            dropId,
            userId: invite.userId,
            affinity: invite.affinity,
            reason: invite.reasons as unknown as Prisma.InputJsonValue,
          },
          update: {
            affinity: invite.affinity,
            reason: invite.reasons as unknown as Prisma.InputJsonValue,
          },
        });
      }
    });

    return { invited: invitations.length, shape };
  }

  /** What the drop is about, read through the lexicon everything else uses. */
  private shapeOf(
    products: ReadonlyArray<{
      title: string;
      description: string;
      offers: ReadonlyArray<{ sellerId: string }>;
    }>,
  ): DropShape {
    const slots = new Set<string>();
    const occasions = new Set<string>();
    const sellerIds = new Set<string>();

    for (const product of products) {
      const text = `${product.title} ${product.description}`;
      for (const slot of detectSlots(text)) slots.add(slot);
      const occasion = detectOccasion(text);
      if (occasion) occasions.add(occasion);
      for (const offer of product.offers) sellerIds.add(offer.sellerId);
    }

    return {
      slots: [...slots],
      occasions: [...occasions],
      sellerIds: [...sellerIds],
      productCount: products.length,
    };
  }

  /**
   * Everything the graph knows about everyone who might want this.
   *
   * Only shoppers with *some* edge are considered — walking the whole user
   * table to score people the graph has never seen would be both slow and
   * pointless, since the kernel would reject every one of them.
   */
  private async candidateSignals(
    productIds: string[],
    shape: DropShape,
  ): Promise<CandidateSignals[]> {
    const edges = await this.prisma.commerceEdge.findMany({
      where: {
        subjectType: GraphNode.USER,
        kind: {
          in: [
            GraphEdge.NEEDS,
            GraphEdge.SHOPS_FOR,
            GraphEdge.BUYS_FROM,
            GraphEdge.SAVED,
            GraphEdge.OWNS,
            GraphEdge.CONSIDERED,
            GraphEdge.SEARCHED,
          ],
        },
      },
      select: {
        subjectId: true,
        objectId: true,
        objectType: true,
        kind: true,
        evidence: true,
      },
      take: 20_000,
    });

    // Products the graph says are like the drop's, so taste can be matched
    // without demanding she already owns one of these exact pieces.
    const similar = await this.prisma.productAffinity.findMany({
      where: { productId: { in: productIds }, kind: 'SIMILAR' },
      select: { relatedId: true },
    });
    const tasteSet = new Set([...productIds, ...similar.map((s) => s.relatedId)]);

    const byUser = new Map<string, CandidateSignals>();
    const get = (userId: string): CandidateSignals => {
      const seen = byUser.get(userId);
      if (seen) return seen;
      const fresh: CandidateSignals = {
        userId,
        needsSlots: [],
        occasions: [],
        sellerIds: [],
        tasteMatches: 0,
        searchHits: 0,
      };
      byUser.set(userId, fresh);
      return fresh;
    };

    for (const edge of edges) {
      const row = get(edge.subjectId) as {
        userId: string;
        needsSlots: string[];
        occasions: string[];
        sellerIds: string[];
        tasteMatches: number;
        searchHits: number;
      };
      const evidence = (edge.evidence ?? {}) as Record<string, unknown>;

      switch (edge.kind) {
        case GraphEdge.NEEDS:
          if (typeof evidence['slot'] === 'string') {
            row.needsSlots.push(evidence['slot']);
          }
          break;
        case GraphEdge.SHOPS_FOR:
          if (typeof evidence['occasion'] === 'string') {
            row.occasions.push(evidence['occasion']);
          }
          break;
        case GraphEdge.BUYS_FROM:
          row.sellerIds.push(edge.objectId);
          break;
        case GraphEdge.SEARCHED: {
          // A term counts only when the drop plausibly answers it.
          const term = evidence['term'];
          if (
            typeof term === 'string' &&
            shape.slots.some((slot) =>
              term.toLowerCase().includes(slot.toLowerCase()),
            )
          ) {
            row.searchHits += 1;
          }
          break;
        }
        default:
          if (
            edge.objectType === GraphNode.PRODUCT &&
            tasteSet.has(edge.objectId)
          ) {
            row.tasteMatches += 1;
          }
          break;
      }
    }

    return [...byUser.values()];
  }

  // ── Running and measuring ──────────────────────────────────────────────

  /** Move a drop through its states. Guarded, because they are not reversible. */
  async setStatus(dropId: string, status: DropStatus, sellerId?: string) {
    const drop = await this.requireOwned(dropId, sellerId);

    const allowed: Record<DropStatus, DropStatus[]> = {
      DRAFT: [DropStatus.SCHEDULED, DropStatus.CANCELLED],
      SCHEDULED: [DropStatus.LIVE, DropStatus.CANCELLED],
      LIVE: [DropStatus.ENDED],
      ENDED: [],
      CANCELLED: [],
    };
    if (!allowed[drop.status].includes(status)) {
      throw new BadRequestException(
        `A ${drop.status.toLowerCase()} drop cannot become ${status.toLowerCase()}`,
      );
    }

    // The same include the list uses. A status change that returned a drop
    // with an empty product list would blank the screen it was made from —
    // which is exactly what the first version did.
    return this.prisma.drop.update({
      where: { id: dropId },
      data: { status },
      include: {
        products: {
          orderBy: { position: 'asc' },
          include: {
            product: {
              select: {
                id: true,
                title: true,
                minPriceSyp: true,
                media: {
                  take: 1,
                  orderBy: { sortOrder: 'asc' },
                  select: { url: true, blurHash: true },
                },
              },
            },
          },
        },
      },
    });
  }

  /**
   * What a shopper can see.
   *
   * The whole of early access lives here. An invited woman sees an
   * `EARLY_ACCESS` drop from `earlyAccessAt`; everybody else from `startsAt`;
   * and an `INVITE_ONLY` drop is invisible to anyone without a row.
   */
  async visibleTo(userId: string | null, now = new Date()) {
    // The whole invitation, not just its existence. The reason the graph
    // picked her is what turns a launch into an invitation, and the first
    // version fetched only the drop id — so every card fell back to the
    // generic subtitle and the feature's central claim never reached a screen.
    const invited = userId
      ? await this.prisma.dropInvite.findMany({
          where: { userId },
          select: {
            dropId: true,
            affinity: true,
            reason: true,
            openedAt: true,
          },
        })
      : [];
    const invitedIds = invited.map((i) => i.dropId);
    const inviteOf = new Map(invited.map((i) => [i.dropId, i]));

    const drops = await this.prisma.drop.findMany({
      where: {
        status: { in: [DropStatus.SCHEDULED, DropStatus.LIVE] },
        OR: [
          // Open to everyone, and open now.
          { audience: DropAudience.EVERYONE, startsAt: { lte: now } },
          // Early access, and she is on the list.
          {
            audience: DropAudience.EARLY_ACCESS,
            id: { in: invitedIds },
            OR: [
              { earlyAccessAt: { lte: now } },
              { earlyAccessAt: null, startsAt: { lte: now } },
            ],
          },
          // Early access, open to everyone now.
          { audience: DropAudience.EARLY_ACCESS, startsAt: { lte: now } },
          // Invite only, and she is on the list.
          {
            audience: DropAudience.INVITE_ONLY,
            id: { in: invitedIds },
            startsAt: { lte: now },
          },
        ],
        AND: [{ OR: [{ endsAt: null }, { endsAt: { gt: now } }] }],
      },
      include: {
        products: {
          orderBy: { position: 'asc' },
          include: {
            product: {
              select: {
                id: true,
                title: true,
                minPriceSyp: true,
                media: { take: 1, orderBy: { sortOrder: 'asc' }, select: { url: true } },
              },
            },
          },
        },
        seller: { select: { id: true, name: true } },
      },
      orderBy: { startsAt: 'desc' },
      take: 20,
    });

    const invitedSet = new Set(invitedIds);
    return drops.map((drop) => ({
      drop,
      invite: inviteOf.get(drop.id) ?? null,
      isInvited: invitedSet.has(drop.id),
      // Early *for her* — she is seeing it before it opens generally.
      isEarly:
        drop.audience === DropAudience.EARLY_ACCESS &&
        invitedSet.has(drop.id) &&
        drop.startsAt > now,
    }));
  }

  /** She looked. Recorded once, so precision is a real rate. */
  async markOpened(dropId: string, userId: string): Promise<void> {
    await this.prisma.dropInvite.updateMany({
      where: { dropId, userId, openedAt: null },
      data: { openedAt: new Date() },
    });
  }

  /**
   * She bought something from it.
   *
   * Called from the order pipeline rather than guessed: a conversion is a
   * purchase of a product this drop carries, by somebody it invited, while it
   * was running.
   */
  async markConverted(userId: string, productIds: string[]): Promise<number> {
    if (!productIds.length) return 0;
    const now = new Date();

    const drops = await this.prisma.drop.findMany({
      where: {
        status: { in: [DropStatus.LIVE, DropStatus.SCHEDULED] },
        startsAt: { lte: now },
        products: { some: { productId: { in: productIds } } },
      },
      select: { id: true },
    });
    if (!drops.length) return 0;

    const result = await this.prisma.dropInvite.updateMany({
      where: {
        userId,
        dropId: { in: drops.map((d) => d.id) },
        convertedAt: null,
      },
      data: { convertedAt: now },
    });
    return result.count;
  }

  /** Her own drops, newest first. */
  async forSeller(sellerId: string, limit = 20) {
    return this.prisma.drop.findMany({
      where: { sellerId },
      orderBy: { startsAt: 'desc' },
      take: limit,
      include: {
        products: {
          orderBy: { position: 'asc' },
          include: {
            product: {
              select: {
                id: true,
                title: true,
                minPriceSyp: true,
                media: {
                  take: 1,
                  orderBy: { sortOrder: 'asc' },
                  select: { url: true, blurHash: true },
                },
              },
            },
          },
        },
      },
    });
  }

  /** How it did. */
  async performance(dropId: string, sellerId?: string) {
    await this.requireOwned(dropId, sellerId);
    const invites = await this.prisma.dropInvite.findMany({
      where: { dropId },
      select: {
        affinity: true,
        notifiedAt: true,
        openedAt: true,
        convertedAt: true,
      },
    });
    return measureDrop(invites);
  }

  private async requireOwned(dropId: string, sellerId?: string) {
    const drop = await this.prisma.drop.findUnique({ where: { id: dropId } });
    if (!drop) throw new NotFoundException('Drop not found');
    if (sellerId && drop.sellerId !== sellerId) {
      // 404 rather than 403: another seller's drop is not hers to know about.
      throw new NotFoundException('Drop not found');
    }
    return drop;
  }

  /**
   * Open the drops whose hour has come, and close the ones whose time is up.
   *
   * State transitions by clock rather than by somebody remembering. Runs on
   * the market sweep.
   */
  async advance(now = new Date()): Promise<{ opened: number; closed: number }> {
    const opened = await this.prisma.drop.updateMany({
      where: { status: DropStatus.SCHEDULED, startsAt: { lte: now } },
      data: { status: DropStatus.LIVE },
    });
    const closed = await this.prisma.drop.updateMany({
      where: {
        status: DropStatus.LIVE,
        endsAt: { not: null, lte: now },
      },
      data: { status: DropStatus.ENDED },
    });
    return { opened: opened.count, closed: closed.count };
  }
}

export type { Invitation };
