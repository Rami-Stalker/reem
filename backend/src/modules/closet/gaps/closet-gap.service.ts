import { Injectable, NotFoundException } from '@nestjs/common';
import { ClosetGap, ClosetGapStatus, ClosetItem, Prisma } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { ClosetService } from '../closet.service';
import { ComputedGap, computeGaps } from './gap-engine';

/**
 * Persisting what the engine computed.
 *
 * The engine is pure and the database is not, so the seam between them is this
 * one class, and it has exactly one interesting decision in it: what happens to
 * a gap that stops computing.
 *
 * It is not deleted. A gap that no longer appears is either FILLED — she bought
 * the skirt — or STALE, meaning the closet moved underneath it. Keeping both
 * gives the feature a memory: the closet can say "لأنك ضفتِ التنورة" instead of
 * silently dropping a card she was looking at yesterday, and a dismissal
 * recorded once keeps suppressing the same gap for as long as it keeps
 * recomputing.
 */
@Injectable()
export class ClosetGapService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly closet: ClosetService,
  ) {}

  /**
   * Recompute every gap for one closet.
   *
   * Cheap enough to run on every closet write — one snapshot read and a handful
   * of upserts against at most `MAX_GAPS` rows — so there is no scheduler, no
   * staleness window and no "recompute" button she has to find. Gaps are a
   * function of her wardrobe, and they update when her wardrobe does.
   */
  async recompute(userId: string): Promise<ClosetGap[]> {
    const closet = await this.closet.findOrCreate(userId);

    // The switch is honoured here rather than at the read, so turning
    // suggestions off actually stops the computation and clears what is on
    // screen instead of merely hiding it.
    if (!closet.suggestionsEnabled) {
      await this.prisma.closetGap.updateMany({
        where: { closetId: closet.id, status: ClosetGapStatus.OPEN },
        data: { status: ClosetGapStatus.STALE },
      });
      return [];
    }

    const snapshot = await this.closet.snapshot(userId);
    const computed = computeGaps(snapshot);
    const fingerprints = computed.map((gap) => gap.fingerprint);

    await this.prisma.$transaction(async (tx) => {
      for (const gap of computed) {
        await tx.closetGap.upsert({
          where: {
            closetId_fingerprint: { closetId: closet.id, fingerprint: gap.fingerprint },
          },
          create: { closetId: closet.id, ...toRow(gap) },
          // A gap that recomputes returns to OPEN unless she dismissed it —
          // that is what makes a dismissal durable and a fill reversible.
          update: {
            ...toRow(gap),
            computedAt: new Date(),
            status: ClosetGapStatus.OPEN,
          },
        });
      }

      // Anything that stopped computing and was not dismissed is superseded.
      // FILLED rows are left alone: they are the record of the engine being
      // right, and re-marking them stale would erase it.
      await tx.closetGap.updateMany({
        where: {
          closetId: closet.id,
          status: ClosetGapStatus.OPEN,
          fingerprint: { notIn: fingerprints.length ? fingerprints : ['—'] },
        },
        data: { status: ClosetGapStatus.STALE },
      });

      await tx.closet.update({
        where: { id: closet.id },
        data: { gapsComputedAt: new Date() },
      });
    });

    // Dismissals are re-applied by `computeGaps` on the next pass; here they
    // are simply never returned.
    return this.list(userId);
  }

  async list(userId: string, limit = 12): Promise<ClosetGap[]> {
    const closet = await this.closet.findOrCreate(userId);
    return this.prisma.closetGap.findMany({
      where: { closetId: closet.id, status: ClosetGapStatus.OPEN },
      include: { look: { select: { id: true, title: true, occasion: true } } },
      orderBy: [{ priority: 'desc' }, { fingerprint: 'asc' }],
      take: limit,
    });
  }

  async require(userId: string, gapId: string): Promise<ClosetGap> {
    const gap = await this.prisma.closetGap.findFirst({
      where: { id: gapId, closet: { userId } },
    });
    if (!gap) throw new NotFoundException('Gap not found');
    return gap;
  }

  /**
   * She said no.
   *
   * Recorded on the row rather than in a preference blob so it survives the gap
   * being recomputed, and so the reason it is not on screen is inspectable. The
   * fingerprint is stable across recomputes precisely so this can work.
   */
  async dismiss(userId: string, gapId: string): Promise<ClosetGap> {
    await this.require(userId, gapId);
    return this.prisma.closetGap.update({
      where: { id: gapId },
      data: { status: ClosetGapStatus.DISMISSED, dismissedAt: new Date() },
    });
  }

  async restore(userId: string, gapId: string): Promise<ClosetGap> {
    await this.require(userId, gapId);
    return this.prisma.closetGap.update({
      where: { id: gapId },
      data: { status: ClosetGapStatus.OPEN, dismissedAt: null },
    });
  }

  /**
   * A new piece closes the gaps it answers.
   *
   * Called when something enters the closet. Matching on slot alone is
   * deliberately generous — an OCCASION gap for a wedding dress is closed by any
   * dress, because the descriptor's occasion list is a guess and she is the one
   * holding the garment. Being slightly too eager to say "تم" is a much smaller
   * failure than leaving a card up that she has already answered.
   */
  async markFilledBy(item: ClosetItem): Promise<number> {
    const result = await this.prisma.closetGap.updateMany({
      where: {
        closetId: item.closetId,
        status: ClosetGapStatus.OPEN,
        slot: item.slot,
      },
      data: {
        status: ClosetGapStatus.FILLED,
        filledByItemId: item.id,
        filledAt: new Date(),
      },
    });
    return result.count;
  }

  /** Recently closed gaps — the closet's evidence that it was useful. */
  async recentlyFilled(userId: string, limit = 5) {
    const closet = await this.closet.findOrCreate(userId);
    return this.prisma.closetGap.findMany({
      where: { closetId: closet.id, status: ClosetGapStatus.FILLED },
      include: { filledByItem: true },
      orderBy: { filledAt: 'desc' },
      take: limit,
    });
  }
}

function toRow(gap: ComputedGap): Omit<Prisma.ClosetGapUncheckedCreateInput, 'closetId'> {
  return {
    kind: gap.kind,
    fingerprint: gap.fingerprint,
    slot: gap.slot,
    occasion: gap.occasion,
    season: gap.season,
    lookId: gap.lookId,
    priority: gap.priority,
    components: gap.components as Prisma.InputJsonValue,
    suggestedColours: gap.suggestedColours,
    suggestedSize: gap.suggestedSize,
    suggestedBudgetMinSyp: gap.suggestedBudgetMinSyp,
    suggestedBudgetMaxSyp: gap.suggestedBudgetMaxSyp,
  };
}
