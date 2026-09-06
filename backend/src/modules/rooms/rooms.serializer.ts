import {
  Room,
  RoomCandidateStatus,
  RoomEvent,
  RoomEventKind,
  RoomMember,
  RoomMemberRole,
} from '@prisma/client';
import { Money } from '../../common/money';
import {
  occasionLabel,
  slotLabel,
} from '../ai-stylist/understanding/stylist-lexicon';
import {
  CandidateFacts,
  Consensus,
  RoomReadiness,
  consensusFor,
  roomReadiness,
} from './kernel/room-readiness';
import { Comparison } from './room-compare.service';
import { CompareVerdict } from './kernel/candidate-comparison';
import { PlanView } from './purchase-plan.service';
import { RoomRecord } from './rooms.service';

/**
 * The wire shape of Reem Rooms.
 *
 * Two rules run through this file.
 *
 * **A candidate never travels as a cart line.** It carries its status, its
 * tally, who put it forward and why — because those are what a person is
 * looking at when she is deciding, and a payload that reduced them to a price
 * and a quantity would have rebuilt the cart on the wire whatever the tables
 * said.
 *
 * **Nothing is announced as a winner.** `consensus` reports a leader *and*
 * whether the room is split, so the screen can say «الآراء منقسمة» rather than
 * crowning a candidate half the room voted against. Votes advise; the woman
 * paying decides.
 */

const ROLE_LABELS: Record<RoomMemberRole, string> = {
  OWNER: 'صاحبة الغرفة',
  CO_SHOPPER: 'بتشتري معك',
  ADVISOR: 'بتنصحك',
  VIEWER: 'بتتفرّج',
};

const EVENT_LABELS: Record<RoomEventKind, string> = {
  ROOM_CREATED: 'فتحت الغرفة',
  MEMBER_JOINED: 'انضمّت للغرفة',
  MEMBER_INVITED: 'دعت حدا',
  DECISION_ADDED: 'ضافت قرار',
  CANDIDATE_ADDED: 'اقترحت قطعة',
  CANDIDATE_REMOVED: 'شالت اقتراح',
  VOTE_CAST: 'صوّتت',
  COMMENT_ADDED: 'علّقت',
  DECISION_RESOLVED: 'حسمت قرار',
  DECISION_SKIPPED: 'قرّرت تتخطّى',
  PLAN_DRAWN: 'جهّزت الخطة',
  PLAN_ORDERED: 'اشترت',
};

const CANDIDATE_LABELS: Record<RoomCandidateStatus, string> = {
  CANDIDATE: 'مقترحة',
  SHORTLISTED: 'بالقائمة القصيرة',
  CHOSEN: 'المختارة',
  REJECTED: 'مستبعدة',
};

type Candidate = RoomRecord['decisions'][number]['candidates'][number];

function candidateFacts(candidate: Candidate): CandidateFacts {
  const stock = candidate.offerVariant?.stock ?? candidate.offer.stock;
  return {
    id: candidate.id,
    status: candidate.status,
    quantity: candidate.quantity,
    votesUp: candidate.votesUp,
    votesDown: candidate.votesDown,
    voteScore: candidate.voteScore,
    // Price is not needed for consensus; the plan prices things properly.
    unitPriceSyp: null,
    purchasable:
      candidate.offer.status === 'ACTIVE' &&
      candidate.offer.isActive &&
      stock >= candidate.quantity,
  };
}

export function serializeCandidate(candidate: Candidate) {
  const price = Money.of(
    candidate.offerVariant?.price ?? candidate.offer.price,
    candidate.offer.currency,
  );
  const stock = candidate.offerVariant?.stock ?? candidate.offer.stock;

  return {
    id: candidate.id,
    status: candidate.status,
    status_label: CANDIDATE_LABELS[candidate.status],
    position: candidate.position,
    quantity: candidate.quantity,

    offer_id: candidate.offerId,
    offer_variant_id: candidate.offerVariantId,
    product_id: candidate.productId,
    title: candidate.offer.product.title,
    image: candidate.offer.product.media[0]?.url ?? null,
    variant: candidate.offerVariant?.variant.name ?? null,
    seller: {
      id: candidate.offer.seller.id,
      name: candidate.offer.seller.name,
    },
    price: price.toJSON(),

    /// Surfaced on the card, so a piece that sold out mid-argument says so
    /// where the argument is happening rather than at the payment step.
    available:
      candidate.offer.status === 'ACTIVE' &&
      candidate.offer.isActive &&
      stock >= candidate.quantity,

    votes_up: candidate.votesUp,
    votes_down: candidate.votesDown,
    vote_score: candidate.voteScore,

    added_by_id: candidate.addedById,
    /// Why she put it forward, and why it lost. The argument, kept.
    note: candidate.note,
    rejection_note: candidate.rejectionNote,
  };
}

export function serializeConsensus(consensus: Consensus) {
  return {
    leader_id: consensus.leaderId,
    runner_up_id: consensus.runnerUpId,
    margin: consensus.margin,
    voters: consensus.voters,
    /// The room is split. Said plainly rather than resolved by arithmetic.
    contested: consensus.contested,
    /// Nobody voted. A different thing from a tie, and worth saying differently.
    silent: consensus.silent,
  };
}

export function serializeDecision(
  decision: RoomRecord['decisions'][number],
  readiness?: RoomReadiness,
) {
  const state = readiness?.decisions.find((entry) => entry.id === decision.id);
  const consensus = consensusFor(decision.candidates.map(candidateFacts));

  return {
    id: decision.id,
    title: decision.title,
    note: decision.note,
    slot: decision.slot,
    slot_label: decision.slot ? slotLabel(decision.slot) : null,
    status: decision.status,
    pick_count: decision.pickCount,
    position: decision.position,
    is_required: decision.isRequired,
    /// The room proposed this one; she did not. Rendered more quietly, and it
    /// never blocks readiness.
    is_suggested: decision.isSuggested,

    /// How many more must be chosen. Zero when the question is answered.
    remaining: state?.remaining ?? Math.max(0, decision.pickCount),
    settled: state?.settled ?? false,
    blockers: state?.blockers.map((blocker) => blocker.code) ?? [],

    consensus: serializeConsensus(consensus),
    candidates: decision.candidates.map(serializeCandidate),
  };
}

export function serializeMember(member: RoomMember) {
  return {
    id: member.id,
    user_id: member.userId,
    name: member.displayName,
    role: member.role,
    role_label: ROLE_LABELS[member.role],
    status: member.status,
    joined_at: member.joinedAt.toISOString(),
  };
}

export function serializeRoom(room: RoomRecord, readiness?: RoomReadiness) {
  // A room knows how far along it is whether or not a purchase plan exists yet.
  //
  // Readiness used to arrive only from the plan, so a room she had not drawn a
  // plan for reported `readiness: null` — which meant the progress rail was
  // blank, no blocker was ever named, and every decision fell back to
  // `remaining = pickCount`, telling her nothing was chosen when something was.
  // That is backwards: readiness is what tells her the room is *ready for* a
  // plan, so it has to exist before one does.
  //
  // The plan's own readiness still wins when passed, because it prices the
  // candidates properly; this fallback only needs their purchasability, which
  // `candidateFacts` already works out.
  const state =
    readiness ??
    roomReadiness(
      room.decisions.map((decision) => ({
        id: decision.id,
        title: decision.title,
        status: decision.status,
        pickCount: decision.pickCount,
        isRequired: decision.isRequired,
        isSuggested: decision.isSuggested,
        candidates: decision.candidates.map(candidateFacts),
      })),
    );

  return {
    id: room.id,
    kind: room.kind,
    status: room.status,
    title: room.title,
    note: room.note,
    occasion: room.occasion,
    occasion_label: occasionLabel(room.occasion),
    target_date: room.targetDate?.toISOString() ?? null,
    cover_url: room.coverUrl,

    budget_min: room.budgetMinSyp ? Money.of(room.budgetMinSyp, 'SYP').toJSON() : null,
    budget_max: room.budgetMaxSyp ? Money.of(room.budgetMaxSyp, 'SYP').toJSON() : null,

    recipient_name: room.recipientName,
    is_surprise: room.isSurprise,

    /// Present only once she has shared. The client builds the link from it.
    share_slug: room.shareSlug,
    share_role: room.shareRole,

    decisions_count: room.decisionsCount,
    candidates_count: room.candidatesCount,
    members_count: room.membersCount,
    last_activity_at: room.lastActivityAt.toISOString(),

    /// The progress rail, and the reason a room card can say "قطعة وحدة وبتخلص"
    /// instead of a count of things in a basket.
    readiness: state
      ? {
          ready: state.ready,
          progress: Math.round(state.progress * 100) / 100,
          settled_required: state.settledRequired,
          total_required: state.totalRequired,
          blockers: state.blockers.map((blocker) => ({
            code: blocker.code,
            decision_id: blocker.decisionId,
            decision_title: blocker.decisionTitle,
          })),
        }
      : null,

    members: room.members.map(serializeMember),
    decisions: room.decisions.map((decision) => serializeDecision(decision, state)),
    created_at: room.createdAt.toISOString(),
  };
}

/** The compact form, for the rooms list. */
export function serializeRoomCard(room: RoomRecord, readiness?: RoomReadiness) {
  const full = serializeRoom(room, readiness);
  return {
    id: full.id,
    kind: full.kind,
    status: full.status,
    title: full.title,
    occasion_label: full.occasion_label,
    target_date: full.target_date,
    cover_url:
      full.cover_url ??
      room.decisions
        .flatMap((decision) => decision.candidates)
        .find((candidate) => candidate.offer.product.media[0]?.url)?.offer.product
        .media[0]?.url ??
      null,
    decisions_count: full.decisions_count,
    candidates_count: full.candidates_count,
    members_count: full.members_count,
    readiness: full.readiness,
    last_activity_at: full.last_activity_at,
  };
}

type TimelineEvent = RoomEvent & {
  actor?: { id: string; name: string; imageUrl: string | null } | null;
};

export function serializeEvent(event: TimelineEvent) {
  return {
    id: event.id,
    kind: event.kind,
    /// Rendered from the code rather than stored as prose, so the timeline
    /// reads correctly in a second language without a backfill.
    label: EVENT_LABELS[event.kind],
    actor: event.actor
      ? { id: event.actor.id, name: event.actor.name, image: event.actor.imageUrl }
      : null,
    payload: event.payload,
    created_at: event.createdAt.toISOString(),
  };
}

export function serializePlan(view: PlanView) {
  const { plan, budget } = view;

  return {
    id: plan.id,
    room_id: plan.roomId,
    status: plan.status,
    version: plan.version,
    order_id: plan.orderId,

    /// Grouped by stage on the wire, because that is how the screen reads and
    /// because "now" and "later" are the plan's whole reason for existing.
    now: plan.items
      .filter((item) => item.stage === 'NOW')
      .map(serializePlanItem),
    later: plan.items
      .filter((item) => item.stage === 'LATER')
      .map(serializePlanItem),

    /// Computed at read time, never stored — see `PurchasePlanService`.
    total: Money.of(String(budget.totalSyp), 'SYP').toJSON(),
    budget: {
      verdict: budget.verdict,
      min: budget.minSyp ? Money.of(String(budget.minSyp), 'SYP').toJSON() : null,
      max: budget.maxSyp ? Money.of(String(budget.maxSyp), 'SYP').toJSON() : null,
      over_by: budget.overBySyp
        ? Money.of(String(budget.overBySyp), 'SYP').toJSON()
        : null,
      unpriced_count: budget.unpricedCount,
    },
    unavailable_item_ids: view.unavailable,
    created_at: plan.createdAt.toISOString(),
  };
}

function serializePlanItem(item: PlanView['plan']['items'][number]) {
  const price = Money.of(
    item.offerVariant?.price ?? item.offer.price,
    item.offer.currency,
  );

  return {
    id: item.id,
    stage: item.stage,
    quantity: item.quantity,
    /// Which question this line answers. A plan line that could not say what it
    /// was decided *for* would be a cart line again.
    decision: item.decision
      ? { id: item.decision.id, title: item.decision.title }
      : null,
    offer_id: item.offerId,
    offer_variant_id: item.offerVariantId,
    title: item.offer.product.title,
    image: item.offer.product.media[0]?.url ?? null,
    variant: item.offerVariant?.variant.name ?? null,
    seller: { id: item.offer.seller.id, name: item.offer.seller.name },
    unit_price: price.toJSON(),
    line_total: price.times(item.quantity).toJSON(),
  };
}

export function serializeComment(
  comment: Awaited<
    ReturnType<
      import('./room-collaboration.service').RoomCollaborationService['comments']
    >
  >[number],
) {
  return {
    id: comment.id,
    body: comment.body,
    decision_id: comment.decisionId,
    candidate_id: comment.candidateId,
    member: {
      id: comment.member.id,
      name: comment.member.displayName ?? comment.member.user.name,
      image: comment.member.user.imageUrl,
      role: comment.member.role,
      role_label: ROLE_LABELS[comment.member.role],
    },
    created_at: comment.createdAt.toISOString(),
  };
}

export function serializeRoomForShare(room: Room) {
  return { id: room.id, title: room.title, share_slug: room.shareSlug };
}

// ── Comparison ──────────────────────────────────────────────────────────

/**
 * What the comparison found, in one sentence.
 *
 * Rendered from a code like every other advisory here. Note what none of them
 * say: "buy this one". `ONE_CHEAPEST_AND_BEST` names a candidate because that
 * is a fact about the options — it wins every measurable row — and stops short
 * of the recommendation, because the room's job is to make the difference
 * legible and hers is to choose.
 */
const VERDICT_LABELS: Record<CompareVerdict, string> = {
  IDENTICAL: 'الخياران متطابقين بكل شي — القرار ذوق.',
  ONE_CHEAPEST_AND_BEST: 'وحدة منهن أحسن بكل شي منقدر نقيسه.',
  CHEAPEST_DIFFERS: 'في فروقات — الأرخص مو بالضرورة الأنسب.',
  TRADE_OFF: 'كل وحدة أحسن بشي — القرار إلك.',
};

export function serializeComparison(comparison: Comparison) {
  return {
    decision_id: comparison.decisionId,
    decision_title: comparison.decisionTitle,
    candidate_ids: comparison.candidateIds,

    /**
     * Ordered most-decisive first, with the rows they agree on last and marked.
     * The client collapses those — a comparison that repeats what is identical
     * is a spreadsheet, not a decision.
     */
    rows: comparison.rows.map((row) => ({
      key: row.key,
      label: row.label,
      direction: row.direction,
      differs: row.differs,
      values: Object.fromEntries(
        Object.entries(row.values).map(([id, cell]) => [
          id,
          {
            display: cell.display,
            /// Set only where a row has a direction and the values differ.
            /// Ties mark every winner rather than picking one.
            best: cell.best ?? false,
          },
        ]),
      ),
    })),

    consensus: serializeConsensus(comparison.consensus),
    verdict: {
      code: comparison.verdict.code,
      label: VERDICT_LABELS[comparison.verdict.code],
      candidate_id: comparison.verdict.candidateId,
    },
    comment_counts: comparison.commentCounts,
  };
}
