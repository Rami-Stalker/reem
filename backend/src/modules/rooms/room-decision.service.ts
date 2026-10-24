import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  OfferStatus,
  OutfitSlot,
  RoomCandidate,
  RoomCandidateStatus,
  RoomDecision,
  RoomDecisionStatus,
  RoomEventKind,
  RoomStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { RoomAccessService } from './room-access.service';
import { RoomEventService } from './room-event.service';

/**
 * Decisions and the candidates competing to answer them.
 *
 * This is where the feature stops being a nicer cart. `addCandidate` does not
 * add something to be bought — it proposes an answer to a question, alongside
 * the others already proposed. `choose` is the moment a purchase intention
 * actually forms, and it is a separate, deliberate act with a name.
 *
 * The rule that keeps the two apart: **nothing is ever bought because it was
 * added.** A cart conflates proposing and deciding, which is why carts fill up
 * with things nobody decided on.
 */
@Injectable()
export class RoomDecisionService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: RoomAccessService,
    private readonly events: RoomEventService,
  ) {}

  // ── Decisions ─────────────────────────────────────────────────────────

  async addDecision(
    roomId: string,
    userId: string,
    input: {
      title: string;
      note?: string | null;
      slot?: OutfitSlot | null;
      pickCount?: number;
      isRequired?: boolean;
    },
  ): Promise<RoomDecision> {
    await this.access.require(roomId, userId, 'decide');
    const title = input.title.trim();
    if (!title) throw new BadRequestException('Name the decision');

    const last = await this.prisma.roomDecision.findFirst({
      where: { roomId },
      orderBy: { position: 'desc' },
      select: { position: true },
    });

    const decision = await this.prisma.roomDecision.create({
      data: {
        roomId,
        title,
        note: input.note ?? null,
        slot: input.slot ?? null,
        pickCount: Math.max(1, input.pickCount ?? 1),
        isRequired: input.isRequired ?? true,
        position: (last?.position ?? -1) + 1,
      },
    });

    await this.refreshCounts(roomId);
    await this.events.record(roomId, RoomEventKind.DECISION_ADDED, userId, {
      title: decision.title,
    });
    return decision;
  }

  async updateDecision(
    roomId: string,
    userId: string,
    decisionId: string,
    patch: {
      title?: string;
      note?: string | null;
      pickCount?: number;
      isRequired?: boolean;
    },
  ): Promise<RoomDecision> {
    await this.access.require(roomId, userId, 'decide');
    await this.requireDecision(roomId, decisionId);

    return this.prisma.roomDecision.update({
      where: { id: decisionId },
      data: {
        ...(patch.title !== undefined ? { title: patch.title.trim() } : {}),
        ...(patch.note !== undefined ? { note: patch.note } : {}),
        ...(patch.pickCount !== undefined
          ? { pickCount: Math.max(1, patch.pickCount) }
          : {}),
        ...(patch.isRequired !== undefined ? { isRequired: patch.isRequired } : {}),
        // Editing a decision she was only suggested makes it hers. Without this
        // a room could never promote its own suggestion into a real question.
        isSuggested: false,
      },
    });
  }

  /** Reorder the questions — the dress before the shoes. */
  async reorderDecisions(
    roomId: string,
    userId: string,
    orderedIds: string[],
  ): Promise<void> {
    await this.access.require(roomId, userId, 'decide');
    await this.prisma.$transaction(
      orderedIds.map((id, index) =>
        this.prisma.roomDecision.updateMany({
          where: { id, roomId },
          data: { position: index },
        }),
      ),
    );
  }

  async removeDecision(
    roomId: string,
    userId: string,
    decisionId: string,
  ): Promise<void> {
    await this.access.require(roomId, userId, 'decide');
    await this.requireDecision(roomId, decisionId);
    await this.prisma.roomDecision.delete({ where: { id: decisionId } });
    await this.refreshCounts(roomId);
  }

  /**
   * Decide against buying anything for this.
   *
   * A real outcome, and one a cart cannot record: removing a line from a cart
   * is indistinguishable from never having added it, so next week the same
   * question comes back. Here it is settled, with the room's memory of it.
   */
  async skipDecision(
    roomId: string,
    userId: string,
    decisionId: string,
    note?: string,
  ): Promise<RoomDecision> {
    await this.access.require(roomId, userId, 'decide');
    const decision = await this.requireDecision(roomId, decisionId);

    const updated = await this.prisma.roomDecision.update({
      where: { id: decision.id },
      data: {
        status: RoomDecisionStatus.SKIPPED,
        skippedAt: new Date(),
        ...(note ? { note } : {}),
      },
    });

    await this.events.record(roomId, RoomEventKind.DECISION_SKIPPED, userId, {
      title: decision.title,
    });
    return updated;
  }

  // ── Candidates ────────────────────────────────────────────────────────

  /**
   * Put an offer forward as an answer.
   *
   * Available to advisors — a friend who cannot change what gets bought can
   * still say "look at this one", which is most of what asking a friend is for.
   */
  async addCandidate(
    roomId: string,
    userId: string,
    decisionId: string,
    input: {
      offerId: string;
      offerVariantId?: string | null;
      quantity?: number;
      note?: string | null;
    },
  ): Promise<RoomCandidate> {
    await this.access.require(roomId, userId, 'propose');
    const decision = await this.requireDecision(roomId, decisionId);

    const offer = await this.prisma.sellerOffer.findUnique({
      where: { id: input.offerId },
      select: { id: true, productId: true, status: true, isActive: true },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    // Proposing something nobody can buy wastes an argument. Checked here
    // rather than at the plan, where it would be found after the discussion.
    if (offer.status !== OfferStatus.ACTIVE || !offer.isActive) {
      throw new BadRequestException('This listing is not available right now');
    }

    const last = await this.prisma.roomCandidate.findFirst({
      where: { decisionId },
      orderBy: { position: 'desc' },
      select: { position: true },
    });

    // `findFirst` then create/update rather than `upsert`: the unique key
    // includes a nullable column, and Prisma cannot address a compound unique
    // whose component is null — which is the ordinary case here, since most
    // offers have no variant.
    const existing = await this.prisma.roomCandidate.findFirst({
      where: {
        decisionId,
        offerId: input.offerId,
        offerVariantId: input.offerVariantId ?? null,
      },
    });

    // Proposing the same piece twice is enthusiasm, not a second option — but a
    // rejected one being proposed again is a genuine reopening, so it comes back
    // as a candidate.
    //
    // Only a REJECTED one, though. Resetting whatever status it already had
    // meant that re-proposing the piece the room had already settled on
    // silently un-chose it: the candidate dropped back to CANDIDATE while
    // `RoomDecision.status` stayed RESOLVED, leaving a decision that was
    // resolved with nothing chosen — which readiness then reported as resolved
    // *and* blocked by DECISION_UNRESOLVED at the same time. Someone
    // enthusiastically re-adding the winning dress would have quietly undone
    // the room's decision.
    const candidate = existing
      ? existing.status === RoomCandidateStatus.REJECTED
        ? await this.prisma.roomCandidate.update({
            where: { id: existing.id },
            data: {
              status: RoomCandidateStatus.CANDIDATE,
              rejectedAt: null,
              rejectionNote: null,
            },
          })
        : existing
      : await this.prisma.roomCandidate.create({
          data: {
            decisionId,
            offerId: offer.id,
            offerVariantId: input.offerVariantId ?? null,
            productId: offer.productId,
            quantity: Math.max(1, input.quantity ?? 1),
            note: input.note ?? null,
            addedById: userId,
            position: (last?.position ?? -1) + 1,
          },
        });

    await this.refreshCounts(roomId);
    await this.markDeciding(roomId);
    await this.events.record(roomId, RoomEventKind.CANDIDATE_ADDED, userId, {
      decision: decision.title,
      candidateId: candidate.id,
    });
    return candidate;
  }

  async updateCandidate(
    roomId: string,
    userId: string,
    candidateId: string,
    patch: { quantity?: number; note?: string | null; position?: number },
  ): Promise<RoomCandidate> {
    await this.access.require(roomId, userId, 'propose');
    const candidate = await this.requireCandidate(roomId, candidateId);

    return this.prisma.roomCandidate.update({
      where: { id: candidate.id },
      data: {
        ...(patch.quantity !== undefined
          ? { quantity: Math.max(1, patch.quantity) }
          : {}),
        ...(patch.note !== undefined ? { note: patch.note } : {}),
        ...(patch.position !== undefined ? { position: patch.position } : {}),
      },
    });
  }

  async removeCandidate(
    roomId: string,
    userId: string,
    candidateId: string,
  ): Promise<void> {
    const access = await this.access.require(roomId, userId, 'propose');
    const candidate = await this.requireCandidate(roomId, candidateId);

    // An advisor may withdraw her own suggestion; taking somebody else's off
    // the table is deciding, and needs the role that decides.
    if (candidate.addedById !== userId && !access.can('decide')) {
      throw new BadRequestException(
        'Only whoever suggested it, or a co-shopper, can remove it',
      );
    }

    await this.prisma.roomCandidate.delete({ where: { id: candidate.id } });
    await this.refreshCounts(roomId);
    await this.events.record(roomId, RoomEventKind.CANDIDATE_REMOVED, userId, {
      candidateId,
    });
  }

  // ── Deciding ──────────────────────────────────────────────────────────

  /**
   * This one.
   *
   * The moment an intention becomes a purchase — and the only place in Ohara
   * Rooms where that happens. Everything before it is argument.
   *
   * Choosing beyond `pickCount` is refused rather than silently allowed: a
   * question that wanted one answer and got three has not been decided, and
   * quietly buying all three is precisely the cart behaviour this feature
   * exists to replace.
   */
  async choose(
    roomId: string,
    userId: string,
    candidateId: string,
  ): Promise<RoomDecision> {
    await this.access.require(roomId, userId, 'decide');
    const candidate = await this.requireCandidate(roomId, candidateId);
    const decision = await this.prisma.roomDecision.findUniqueOrThrow({
      where: { id: candidate.decisionId },
      include: { candidates: { select: { id: true, status: true } } },
    });

    const alreadyChosen = decision.candidates.filter(
      (c) => c.status === RoomCandidateStatus.CHOSEN && c.id !== candidate.id,
    ).length;

    if (alreadyChosen >= decision.pickCount) {
      throw new BadRequestException(
        `«${decision.title}» already has its ${decision.pickCount} choice(s) — ` +
          'un-choose one first',
      );
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.roomCandidate.update({
        where: { id: candidate.id },
        data: { status: RoomCandidateStatus.CHOSEN, chosenAt: new Date() },
      });

      if (alreadyChosen + 1 >= decision.pickCount) {
        await tx.roomDecision.update({
          where: { id: decision.id },
          data: {
            status: RoomDecisionStatus.RESOLVED,
            resolvedAt: new Date(),
          },
        });
      }
    });

    await this.events.record(roomId, RoomEventKind.DECISION_RESOLVED, userId, {
      decision: decision.title,
      candidateId: candidate.id,
    });
    return this.prisma.roomDecision.findUniqueOrThrow({ where: { id: decision.id } });
  }

  /** Change her mind. The decision reopens. */
  async unchoose(
    roomId: string,
    userId: string,
    candidateId: string,
  ): Promise<RoomDecision> {
    await this.access.require(roomId, userId, 'decide');
    const candidate = await this.requireCandidate(roomId, candidateId);

    await this.prisma.$transaction([
      this.prisma.roomCandidate.update({
        where: { id: candidate.id },
        data: { status: RoomCandidateStatus.SHORTLISTED, chosenAt: null },
      }),
      this.prisma.roomDecision.update({
        where: { id: candidate.decisionId },
        data: { status: RoomDecisionStatus.OPEN, resolvedAt: null },
      }),
    ]);

    return this.prisma.roomDecision.findUniqueOrThrow({
      where: { id: candidate.decisionId },
    });
  }

  /**
   * Rule one out, with the reason.
   *
   * The reason is the point. A room that forgets why it ruled something out
   * invites the same suggestion again next week — usually from the same
   * well-meaning cousin.
   */
  async reject(
    roomId: string,
    userId: string,
    candidateId: string,
    reason?: string,
  ): Promise<RoomCandidate> {
    await this.access.require(roomId, userId, 'decide');
    const candidate = await this.requireCandidate(roomId, candidateId);

    return this.prisma.roomCandidate.update({
      where: { id: candidate.id },
      data: {
        status: RoomCandidateStatus.REJECTED,
        rejectedAt: new Date(),
        rejectionNote: reason ?? null,
      },
    });
  }

  async shortlist(
    roomId: string,
    userId: string,
    candidateId: string,
  ): Promise<RoomCandidate> {
    await this.access.require(roomId, userId, 'decide');
    const candidate = await this.requireCandidate(roomId, candidateId);
    return this.prisma.roomCandidate.update({
      where: { id: candidate.id },
      data: {
        status: RoomCandidateStatus.SHORTLISTED,
        rejectedAt: null,
        rejectionNote: null,
      },
    });
  }

  // ── Internals ─────────────────────────────────────────────────────────

  private async requireDecision(
    roomId: string,
    decisionId: string,
  ): Promise<RoomDecision> {
    const decision = await this.prisma.roomDecision.findFirst({
      where: { id: decisionId, roomId },
    });
    if (!decision) throw new NotFoundException('Decision not found');
    return decision;
  }

  private async requireCandidate(
    roomId: string,
    candidateId: string,
  ): Promise<RoomCandidate> {
    const candidate = await this.prisma.roomCandidate.findFirst({
      where: { id: candidateId, decision: { roomId } },
    });
    if (!candidate) throw new NotFoundException('Candidate not found');
    return candidate;
  }

  private async refreshCounts(roomId: string): Promise<void> {
    const [decisionsCount, candidatesCount] = await Promise.all([
      this.prisma.roomDecision.count({ where: { roomId } }),
      this.prisma.roomCandidate.count({ where: { decision: { roomId } } }),
    ]);
    await this.prisma.room.update({
      where: { id: roomId },
      data: { decisionsCount, candidatesCount, lastActivityAt: new Date() },
    });
  }

  /** A room with candidates in it has moved on from planning. */
  private async markDeciding(roomId: string): Promise<void> {
    await this.prisma.room.updateMany({
      where: { id: roomId, status: RoomStatus.PLANNING },
      data: { status: RoomStatus.DECIDING },
    });
  }
}
