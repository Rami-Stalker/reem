import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import {
  ClosetItemStatus,
  Mission,
  MissionKind,
  MissionStatus,
  SellerOrderStatus,
  Prisma,
  RoomDecisionStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import {
  Criteria,
  CriteriaType,
  MissionEvidence,
  isWorthOffering,
  rankOffers,
  readProgress,
} from '../kernel/missions';

const DAY_MS = 24 * 60 * 60 * 1000;

/** At most this many live at once. A list of chores is not an invitation. */
const MAX_ACTIVE = 3;

/**
 * The mission catalogue.
 *
 * Deliberately short and deliberately unglamorous. Every one of these asks for
 * something whose payoff is the thing itself: a described closet gives better
 * suggestions, a logged wear makes cost-per-wear true, a reviewed dress helps
 * the next woman, a closed decision finishes a room she already started. None
 * of them asks her to browse for the sake of browsing, and none of them pays.
 *
 * `valuePoints` is zero throughout, and that is the point — see the kernel's
 * first rule. Where an act earns standing it does so through the Value
 * collector, on the same evidence, whether or not a mission ever mentioned it.
 */
const CATALOGUE: Array<{
  key: string;
  kind: MissionKind;
  titleAr: string;
  bodyAr: string;
  criteria: Criteria;
  ttlDays: number;
}> = [
  {
    key: 'describe_closet',
    kind: MissionKind.COMPLETE,
    titleAr: 'عرّفي ريم بخزانتكِ',
    bodyAr:
      'في خزانتكِ قطع بلا لون ولا قماش. حين تكملينها، تعرف اقتراحات ريم ما يليق بماذا لديكِ فعلاً.',
    criteria: { type: 'DESCRIBE_CLOSET', target: 5 },
    ttlDays: 21,
  },
  {
    key: 'log_wears',
    kind: MissionKind.COMPLETE,
    titleAr: 'سجّلي ما ارتديتِه هذا الأسبوع',
    bodyAr:
      'كل لبسة تسجّلينها تُظهر الكلفة الحقيقية للقطعة — وتعرفين ما يبقى في الخزانة دون أن تنتبهي.',
    criteria: { type: 'LOG_WEARS', target: 4 },
    ttlDays: 14,
  },
  {
    key: 'review_purchases',
    kind: MissionKind.CONTRIBUTE,
    titleAr: 'شاركي رأيكِ في شيء وصلكِ',
    bodyAr:
      'وصلتكِ طلبات لم تكتبي عنها. رأيكِ هو ما يجعل المرأة التالية تعرف إن كان المقاس مناسباً أم لا.',
    criteria: { type: 'REVIEW_PURCHASES', target: 2 },
    ttlDays: 21,
  },
  {
    key: 'build_look',
    kind: MissionKind.CONTRIBUTE,
    titleAr: 'نسّقي إطلالة من قطعكِ',
    bodyAr:
      'من القطع التي لديكِ، نسّقي إطلالة واحدة. تبقى محفوظة لديكِ، وتعرف ريم كيف تكملها حين ينقصها شيء.',
    criteria: { type: 'BUILD_LOOK', target: 1 },
    ttlDays: 21,
  },
  {
    key: 'close_room_decision',
    kind: MissionKind.COMPLETE,
    titleAr: 'احسمي قراراً مفتوحاً في غرفتكِ',
    bodyAr: 'في غرفة فتحتِها قرار لم يُحسم بعد. قرار واحد يقرّبكِ من النهاية.',
    criteria: { type: 'CLOSE_ROOM_DECISION', target: 1 },
    ttlDays: 14,
  },
  {
    key: 'explore_categories',
    kind: MissionKind.DISCOVER,
    titleAr: 'تصفّحي قسمين لم تزوريهما',
    bodyAr: 'في ريم أقسام لم تفتحيها قط. مرة واحدة تكفي لتعرفي إن كان فيها ما يناسبكِ.',
    criteria: { type: 'EXPLORE_CATEGORIES', target: 2 },
    ttlDays: 14,
  },
];

/**
 * Reem Missions.
 *
 * An evaluator over evidence, not a task engine. Progress is recomputed from
 * the source tables on every read and never incremented by a client, which is
 * why there is no endpoint here that says "I did it": a mission is completed
 * by doing the thing, and Reem notices.
 */
@Injectable()
export class MissionsService {
  private readonly logger = new Logger(MissionsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** Install the catalogue. Idempotent; safe on every boot. */
  async seed(): Promise<number> {
    for (const entry of CATALOGUE) {
      const data = {
        kind: entry.kind,
        titleAr: entry.titleAr,
        bodyAr: entry.bodyAr,
        criteria: entry.criteria as unknown as Prisma.InputJsonValue,
        ttlDays: entry.ttlDays,
        valuePoints: 0,
        isActive: true,
      };
      await this.prisma.mission.upsert({
        where: { key: entry.key },
        create: { key: entry.key, ...data },
        update: data,
      });
    }
    // Anything no longer in the catalogue stops being offered but keeps its
    // history — a completed mission is a fact about her, not about the list.
    await this.prisma.mission.updateMany({
      where: { key: { notIn: CATALOGUE.map((entry) => entry.key) } },
      data: { isActive: false },
    });
    return CATALOGUE.length;
  }

  // ── Evidence ──────────────────────────────────────────────────────────

  /**
   * What the database says about her, per criterion.
   *
   * Every count here reads rows written by other features. Nothing in the
   * missions tables is trusted as evidence of anything — which is what makes
   * the progress number unfakeable from the client.
   */
  async evidence(
    userId: string,
    type: CriteriaType,
    now = new Date(),
  ): Promise<MissionEvidence> {
    switch (type) {
      case 'DESCRIBE_CLOSET': {
        const items = await this.prisma.closetItem.findMany({
          where: { userId, status: ClosetItemStatus.ACTIVE },
          select: { colours: true, materials: true },
        });
        const described = items.filter(
          (item) => item.colours.length > 0 || item.materials.length > 0,
        ).length;
        return { done: described, possible: items.length - described };
      }

      case 'LOG_WEARS': {
        const since = new Date(now.getTime() - 30 * DAY_MS);
        const [logged, owned] = await Promise.all([
          this.prisma.closetItemWear.count({
            where: { item: { userId }, wornOn: { gte: since } },
          }),
          this.prisma.closetItem.count({
            where: { userId, status: ClosetItemStatus.ACTIVE },
          }),
        ]);
        // She can log one wear per piece per day, so what is possible is
        // bounded by what she owns, not by the calendar.
        return { done: logged, possible: owned };
      }

      case 'REVIEW_PURCHASES': {
        const [written, delivered] = await Promise.all([
          this.prisma.productReview.count({ where: { userId } }),
          this.prisma.orderItem.findMany({
            where: {
              // Delivery is tracked per shop, so a woman whose shoes arrived
              // can review them while the rest of the order is still moving.
              sellerOrder: {
                status: SellerOrderStatus.DELIVERED,
                order: { userId },
              },
              productId: { not: null },
            },
            select: { productId: true },
          }),
        ]);
        const reviewed = await this.prisma.productReview.findMany({
          where: { userId },
          select: { productId: true },
        });
        const reviewedIds = new Set(reviewed.map((row) => row.productId));
        const unreviewed = new Set(
          delivered
            .map((row) => row.productId as string)
            .filter((id) => !reviewedIds.has(id)),
        );
        return { done: written, possible: unreviewed.size };
      }

      case 'BUILD_LOOK': {
        const [looks, items] = await Promise.all([
          this.prisma.closetLook.count({ where: { userId, isArchived: false } }),
          this.prisma.closetItem.count({
            where: { userId, status: ClosetItemStatus.ACTIVE },
          }),
        ]);
        // A look needs pieces to be made of. Two is the floor.
        return { done: looks, possible: items >= 2 ? Math.floor(items / 2) : 0 };
      }

      case 'CLOSE_ROOM_DECISION': {
        const [resolved, open] = await Promise.all([
          this.prisma.roomDecision.count({
            where: {
              room: { ownerId: userId },
              status: RoomDecisionStatus.RESOLVED,
            },
          }),
          this.prisma.roomDecision.count({
            where: {
              room: { ownerId: userId },
              status: RoomDecisionStatus.OPEN,
              isRequired: true,
            },
          }),
        ]);
        return { done: resolved, possible: open };
      }

      case 'EXPLORE_CATEGORIES': {
        const rows = await this.prisma.$queryRaw<
          Array<{ seen: bigint; total: bigint }>
        >`
          WITH seen AS (
            SELECT DISTINCT p.category_id
            FROM commerce_edges e
            JOIN products p ON p.id = e.object_id
            WHERE e.subject_type = 'USER'
              AND e.subject_id = ${userId}::uuid
              AND e.object_type = 'PRODUCT'
          ),
          live AS (
            SELECT DISTINCT p.category_id
            FROM products p
            WHERE p.status = 'ACTIVE'
          )
          SELECT (SELECT count(*) FROM seen)::bigint AS seen,
                 (SELECT count(*) FROM live)::bigint AS total
        `;
        const seen = Number(rows[0]?.seen ?? 0);
        const total = Number(rows[0]?.total ?? 0);
        return { done: seen, possible: Math.max(0, total - seen) };
      }
    }
  }

  private criteriaOf(mission: Mission): Criteria {
    return mission.criteria as unknown as Criteria;
  }

  // ── Offering ──────────────────────────────────────────────────────────

  /**
   * Decide what, if anything, to put in front of her.
   *
   * Called on read rather than on a schedule, because whether a mission is
   * worth offering changes the moment she adds a closet item — and a mission
   * list computed at 3am is a list about yesterday's wardrobe.
   */
  async refresh(userId: string, now = new Date()): Promise<void> {
    const missions = await this.prisma.mission.findMany({ where: { isActive: true } });
    const existing = await this.prisma.missionProgress.findMany({
      where: { userId },
    });
    const byMission = new Map(existing.map((row) => [row.missionId, row]));

    // Expire what ran out of time before deciding what to add, so an expired
    // slot can be filled in the same pass.
    const expired = existing.filter(
      (row) =>
        row.status !== MissionStatus.COMPLETED &&
        row.status !== MissionStatus.EXPIRED &&
        row.expiresAt !== null &&
        row.expiresAt < now,
    );
    if (expired.length) {
      await this.prisma.missionProgress.updateMany({
        where: { id: { in: expired.map((row) => row.id) } },
        data: { status: MissionStatus.EXPIRED },
      });
      for (const row of expired) {
        byMission.set(row.missionId, { ...row, status: MissionStatus.EXPIRED });
      }
    }

    const live = [...byMission.values()].filter(
      (row) =>
        row.status === MissionStatus.OFFERED || row.status === MissionStatus.ACTIVE,
    );

    // Re-read progress on the live ones and finish the finished.
    for (const row of live) {
      const mission = missions.find((entry) => entry.id === row.missionId);
      if (!mission) continue;
      const criteria = this.criteriaOf(mission);
      const current = await this.evidence(userId, criteria.type, now);
      // The baseline was fixed when she was asked and never moves. Re-reading
      // it rather than recomputing it is what makes the bar measure what she
      // has done since, instead of what she had already done before.
      const held = (row.evidence ?? {}) as { baseline?: number };
      const evidence = { ...current, baseline: held.baseline ?? current.done };
      const reading = readProgress(criteria, evidence);

      // A mission can stop being finishable after it was offered — she
      // cancelled the order she was going to review, or archived the pieces
      // she was going to describe. Leaving it on the screen is a bar that can
      // never fill, so it is retired instead, and the freed slot goes to
      // something she can actually do.
      const stranded = !reading.complete && evidence.possible < reading.remaining;

      await this.prisma.missionProgress.update({
        where: { id: row.id },
        data: {
          progress: reading.progress,
          evidence: evidence as unknown as Prisma.InputJsonValue,
          status: reading.complete
            ? MissionStatus.COMPLETED
            : stranded
              ? MissionStatus.EXPIRED
              : reading.progress > 0
                ? MissionStatus.ACTIVE
                : MissionStatus.OFFERED,
          completedAt: reading.complete ? (row.completedAt ?? now) : null,
        },
      });
      if (reading.complete) {
        byMission.set(row.missionId, { ...row, status: MissionStatus.COMPLETED });
      } else if (stranded) {
        byMission.set(row.missionId, { ...row, status: MissionStatus.EXPIRED });
      }
    }

    const stillLive = [...byMission.values()].filter(
      (row) =>
        row.status === MissionStatus.OFFERED || row.status === MissionStatus.ACTIVE,
    ).length;

    const room = MAX_ACTIVE - stillLive;
    if (room <= 0) return;

    // Candidates: never offered, or offered and expired long enough ago that
    // asking again is reasonable rather than nagging.
    const candidates: Array<{
      mission: Mission;
      criteria: Criteria;
      evidence: MissionEvidence;
    }> = [];

    for (const mission of missions) {
      const held = byMission.get(mission.id);
      if (held && held.status === MissionStatus.COMPLETED) continue;
      if (held && held.status !== MissionStatus.EXPIRED) continue;
      if (
        held?.status === MissionStatus.EXPIRED &&
        held.offeredAt.getTime() > now.getTime() - 60 * DAY_MS
      ) {
        // Asked recently and she did not take it. That is an answer.
        continue;
      }

      const criteria = this.criteriaOf(mission);
      const current = await this.evidence(userId, criteria.type, now);
      // Offered at zero, always: the baseline is today's count.
      const evidence = { ...current, baseline: current.done };
      if (!isWorthOffering(criteria, evidence)) continue;
      candidates.push({ mission, criteria, evidence });
    }

    for (const candidate of rankOffers(candidates).slice(0, room)) {
      const reading = readProgress(candidate.criteria, candidate.evidence);
      const expiresAt = new Date(
        now.getTime() + candidate.mission.ttlDays * DAY_MS,
      );
      await this.prisma.missionProgress.upsert({
        where: {
          missionId_userId: { missionId: candidate.mission.id, userId },
        },
        create: {
          missionId: candidate.mission.id,
          userId,
          status: MissionStatus.OFFERED,
          progress: reading.progress,
          evidence: candidate.evidence as unknown as Prisma.InputJsonValue,
          offeredAt: now,
          expiresAt,
        },
        update: {
          status: MissionStatus.OFFERED,
          progress: reading.progress,
          evidence: candidate.evidence as unknown as Prisma.InputJsonValue,
          offeredAt: now,
          expiresAt,
          completedAt: null,
        },
      });
    }
  }

  /**
   * Her missions.
   *
   * Refreshes first, so what she sees is what is true now rather than what was
   * true when she last opened the screen.
   */
  async mine(userId: string, now = new Date()) {
    await this.refresh(userId, now);

    const rows = await this.prisma.missionProgress.findMany({
      where: {
        userId,
        status: {
          in: [MissionStatus.OFFERED, MissionStatus.ACTIVE, MissionStatus.COMPLETED],
        },
      },
      include: { mission: true },
      orderBy: [{ status: 'asc' }, { progress: 'desc' }],
    });

    // Completed ones are shown briefly and then get out of the way; a wall of
    // finished badges is the gamification this was built against.
    const recent = new Date(now.getTime() - 14 * DAY_MS);

    return rows
      .filter(
        (row) =>
          row.status !== MissionStatus.COMPLETED ||
          (row.completedAt !== null && row.completedAt > recent),
      )
      .map((row) => {
        const criteria = this.criteriaOf(row.mission);
        const evidence = (row.evidence ?? {
          done: 0,
          possible: 0,
          baseline: 0,
        }) as unknown as MissionEvidence;
        return {
          progress: row,
          mission: row.mission,
          criteria,
          reading: readProgress(criteria, evidence),
          evidence,
        };
      });
  }

  /** One mission, for a detail sheet. */
  async detail(userId: string, missionKey: string, now = new Date()) {
    const mission = await this.prisma.mission.findUnique({
      where: { key: missionKey },
    });
    if (!mission) throw new NotFoundException('Mission not found');

    const criteria = this.criteriaOf(mission);
    const current = await this.evidence(userId, criteria.type, now);
    const progress = await this.prisma.missionProgress.findUnique({
      where: { missionId_userId: { missionId: mission.id, userId } },
    });

    const held = (progress?.evidence ?? {}) as { baseline?: number };
    const evidence = { ...current, baseline: held.baseline ?? current.done };

    return {
      mission,
      criteria,
      evidence,
      reading: readProgress(criteria, evidence),
      progress,
    };
  }

  /**
   * She can decline one.
   *
   * Marked EXPIRED rather than deleted, which is what makes the sixty-day
   * silence in `refresh` work: a mission she turned down is not offered again
   * next time she opens the screen.
   */
  async decline(userId: string, missionKey: string) {
    const mission = await this.prisma.mission.findUnique({
      where: { key: missionKey },
      select: { id: true },
    });
    if (!mission) throw new NotFoundException('Mission not found');

    const progress = await this.prisma.missionProgress.findUnique({
      where: { missionId_userId: { missionId: mission.id, userId } },
    });
    if (!progress) throw new NotFoundException('Mission not offered');

    return this.prisma.missionProgress.update({
      where: { id: progress.id },
      data: { status: MissionStatus.EXPIRED, expiresAt: new Date() },
    });
  }
}
