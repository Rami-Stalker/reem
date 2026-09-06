import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { PurchaseStage } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateOrderDto } from '../orders/dto/create-order.dto';
import { PurchasePlanService } from './purchase-plan.service';
import { RoomAccessService } from './room-access.service';
import { RoomCollaborationService } from './room-collaboration.service';
import { RoomCompareService } from './room-compare.service';
import { RoomDecisionService } from './room-decision.service';
import { RoomEventService } from './room-event.service';
import { RoomsService } from './rooms.service';
import {
  AddCandidateDto,
  CommentDto,
  CreateDecisionDto,
  CreateRoomDto,
  InviteMemberDto,
  CompareDto,
  ListCommentsDto,
  ListRoomsDto,
  RejectCandidateDto,
  ReorderDecisionsDto,
  SetMemberRoleDto,
  SetPlanQuantityDto,
  SetStageDto,
  ShareRoomDto,
  SkipDecisionDto,
  UpdateCandidateDto,
  UpdateDecisionDto,
  UpdateRoomDto,
  VoteDto,
} from './dto/rooms.dto';
import {
  serializeComparison,
  serializeComment,
  serializeEvent,
  serializeMember,
  serializePlan,
  serializeRoom,
  serializeRoomCard,
} from './rooms.serializer';

/**
 * `/rooms` — Intent → Room → Decision → Purchase.
 *
 * Read the routes in order and the shape of the idea is there: a room is
 * created around an intent, decisions are added to it, candidates are proposed
 * against decisions, people vote and argue, one candidate is *chosen*, and only
 * then is a plan drawn and bought.
 *
 * There is no route that adds something to a basket, and none that buys
 * something that was never chosen. `POST /rooms/:id/plan` refuses a room with
 * open decisions and names them — the one place the whole model is enforced
 * rather than implied.
 */
@Controller('rooms')
export class RoomsController {
  constructor(
    private readonly rooms: RoomsService,
    private readonly access: RoomAccessService,
    private readonly decisions: RoomDecisionService,
    private readonly collaboration: RoomCollaborationService,
    private readonly comparison: RoomCompareService,
    private readonly plans: PurchasePlanService,
    private readonly events: RoomEventService,
  ) {}

  // ── Rooms ─────────────────────────────────────────────────────────────

  @Get()
  async list(@CurrentUser('id') userId: string, @Query() dto: ListRoomsDto) {
    const rooms = await this.rooms.list(userId, {
      status: dto.status,
      kind: dto.kind,
      limit: dto.limit,
    });
    return rooms.map((room) => serializeRoomCard(room));
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@CurrentUser('id') userId: string, @Body() dto: CreateRoomDto) {
    const room = await this.rooms.create(userId, {
      title: dto.title,
      kind: dto.kind,
      note: dto.note,
      occasion: dto.occasion,
      targetDate: dto.target_date ? new Date(dto.target_date) : null,
      budgetMinSyp: dto.budget_min_syp ?? null,
      budgetMaxSyp: dto.budget_max_syp ?? null,
      recipientName: dto.recipient_name,
      recipientUserId: dto.recipient_user_id ?? null,
      isSurprise: dto.is_surprise,
      seedFromOccasion: dto.seed_from_occasion,
    });
    return serializeRoom(room);
  }

  @Get(':id')
  async detail(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
  ) {
    const [room, plan] = await Promise.all([
      this.rooms.detail(roomId, userId),
      this.plans.current(roomId, userId),
    ]);
    return {
      ...serializeRoom(room, plan?.readiness),
      // The live plan travels with the room so the "ready to buy" state and the
      // decisions behind it can never disagree on screen.
      plan: plan ? serializePlan(plan) : null,
    };
  }

  @Patch(':id')
  async update(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Body() dto: UpdateRoomDto,
  ) {
    const room = await this.rooms.update(roomId, userId, {
      title: dto.title,
      note: dto.note,
      occasion: dto.occasion,
      targetDate: dto.target_date ? new Date(dto.target_date) : undefined,
      budgetMinSyp: dto.budget_min_syp,
      budgetMaxSyp: dto.budget_max_syp,
      status: dto.status,
      coverUrl: dto.cover_url,
      recipientName: dto.recipient_name,
    });
    return serializeRoom(room);
  }

  @Delete(':id')
  async remove(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
  ) {
    await this.rooms.remove(roomId, userId);
    return { deleted: true };
  }

  @Get(':id/timeline')
  async timeline(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
  ) {
    await this.access.require(roomId, userId);
    const events = await this.events.timeline(roomId);
    return events.map((event) => serializeEvent(event as never));
  }

  // ── Membership ────────────────────────────────────────────────────────

  @Get(':id/members')
  async members(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
  ) {
    await this.access.require(roomId, userId);
    const members = await this.access.members(roomId);
    return members.map(serializeMember);
  }

  @Post(':id/members')
  @HttpCode(HttpStatus.CREATED)
  async invite(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Body() dto: InviteMemberDto,
  ) {
    const member = await this.access.invite(roomId, userId, {
      userId: dto.user_id,
      role: dto.role,
    });
    return serializeMember(member);
  }

  @Patch(':id/members/:memberId')
  async setRole(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
    @Body() dto: SetMemberRoleDto,
  ) {
    return serializeMember(
      await this.access.setRole(roomId, userId, memberId, dto.role),
    );
  }

  @Delete(':id/members/:memberId')
  async removeMember(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
  ) {
    await this.access.remove(roomId, userId, memberId);
    return { removed: true };
  }

  @Post(':id/leave')
  async leave(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
  ) {
    await this.access.leave(roomId, userId);
    return { left: true };
  }

  /** Share, or rotate the link — the same call, because rotation is the only
   *  revocation a link can honestly offer. */
  @Post(':id/share')
  async share(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Body() dto: ShareRoomDto,
  ) {
    const room = await this.access.share(roomId, userId, dto.role);
    return { share_slug: room.shareSlug, share_role: room.shareRole };
  }

  @Delete(':id/share')
  async unshare(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
  ) {
    await this.access.unshare(roomId, userId);
    return { share_slug: null };
  }

  /** Follow somebody's link. Joins at the room's share role, never higher. */
  @Post('join/:slug')
  async join(@CurrentUser('id') userId: string, @Param('slug') slug: string) {
    const access = await this.access.joinByLink(slug, userId);
    const room = await this.rooms.detail(access.room.id, userId);
    return serializeRoom(room);
  }

  // ── Decisions ─────────────────────────────────────────────────────────

  @Post(':id/decisions')
  @HttpCode(HttpStatus.CREATED)
  async addDecision(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Body() dto: CreateDecisionDto,
  ) {
    const decision = await this.decisions.addDecision(roomId, userId, {
      title: dto.title,
      note: dto.note,
      slot: dto.slot,
      pickCount: dto.pick_count,
      isRequired: dto.is_required,
    });
    return { id: decision.id, title: decision.title };
  }

  @Patch(':id/decisions/:decisionId')
  async updateDecision(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('decisionId', ParseUUIDPipe) decisionId: string,
    @Body() dto: UpdateDecisionDto,
  ) {
    const decision = await this.decisions.updateDecision(
      roomId,
      userId,
      decisionId,
      {
        title: dto.title,
        note: dto.note,
        pickCount: dto.pick_count,
        isRequired: dto.is_required,
      },
    );
    return { id: decision.id, title: decision.title };
  }

  @Patch(':id/decisions/order')
  async reorder(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Body() dto: ReorderDecisionsDto,
  ) {
    await this.decisions.reorderDecisions(roomId, userId, dto.decision_ids);
    return { reordered: true };
  }

  @Delete(':id/decisions/:decisionId')
  async removeDecision(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('decisionId', ParseUUIDPipe) decisionId: string,
  ) {
    await this.decisions.removeDecision(roomId, userId, decisionId);
    return { deleted: true };
  }

  /** Decide to buy nothing for this. A real outcome, and it settles the room. */
  @Post(':id/decisions/:decisionId/skip')
  async skip(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('decisionId', ParseUUIDPipe) decisionId: string,
    @Body() dto: SkipDecisionDto,
  ) {
    const decision = await this.decisions.skipDecision(
      roomId,
      userId,
      decisionId,
      dto.note,
    );
    return { id: decision.id, status: decision.status };
  }

  // ── Candidates ────────────────────────────────────────────────────────

  /**
   * Put an offer forward.
   *
   * Note the verb and the absence of its alternative: this proposes an answer,
   * it does not buy anything and it does not put anything in a basket.
   */
  @Post(':id/decisions/:decisionId/candidates')
  @HttpCode(HttpStatus.CREATED)
  async propose(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('decisionId', ParseUUIDPipe) decisionId: string,
    @Body() dto: AddCandidateDto,
  ) {
    const candidate = await this.decisions.addCandidate(
      roomId,
      userId,
      decisionId,
      {
        offerId: dto.offer_id,
        offerVariantId: dto.offer_variant_id ?? null,
        quantity: dto.quantity,
        note: dto.note,
      },
    );
    return { id: candidate.id, status: candidate.status };
  }

  @Patch(':id/candidates/:candidateId')
  async updateCandidate(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('candidateId', ParseUUIDPipe) candidateId: string,
    @Body() dto: UpdateCandidateDto,
  ) {
    const candidate = await this.decisions.updateCandidate(
      roomId,
      userId,
      candidateId,
      { quantity: dto.quantity, note: dto.note, position: dto.position },
    );
    return { id: candidate.id, quantity: candidate.quantity };
  }

  @Delete(':id/candidates/:candidateId')
  async removeCandidate(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('candidateId', ParseUUIDPipe) candidateId: string,
  ) {
    await this.decisions.removeCandidate(roomId, userId, candidateId);
    return { deleted: true };
  }

  /** This one. The moment an intention becomes a purchase. */
  @Post(':id/candidates/:candidateId/choose')
  async choose(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('candidateId', ParseUUIDPipe) candidateId: string,
  ) {
    const decision = await this.decisions.choose(roomId, userId, candidateId);
    return { decision_id: decision.id, status: decision.status };
  }

  @Post(':id/candidates/:candidateId/unchoose')
  async unchoose(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('candidateId', ParseUUIDPipe) candidateId: string,
  ) {
    const decision = await this.decisions.unchoose(roomId, userId, candidateId);
    return { decision_id: decision.id, status: decision.status };
  }

  @Post(':id/candidates/:candidateId/reject')
  async reject(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('candidateId', ParseUUIDPipe) candidateId: string,
    @Body() dto: RejectCandidateDto,
  ) {
    const candidate = await this.decisions.reject(
      roomId,
      userId,
      candidateId,
      dto.reason,
    );
    return { id: candidate.id, status: candidate.status };
  }

  @Post(':id/candidates/:candidateId/shortlist')
  async shortlist(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('candidateId', ParseUUIDPipe) candidateId: string,
  ) {
    const candidate = await this.decisions.shortlist(roomId, userId, candidateId);
    return { id: candidate.id, status: candidate.status };
  }

  /**
   * Put the options side by side.
   *
   * `only` narrows to two or three candidates — the ordinary case, since the
   * useful comparison is between the ones she has already shortlisted. Omitted,
   * it compares everything still in the running; rejected candidates are never
   * included, because re-presenting them is re-arguing a settled point.
   */
  @Get(':id/decisions/:decisionId/compare')
  async compare(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('decisionId', ParseUUIDPipe) decisionId: string,
    @Query() dto: CompareDto,
  ) {
    return serializeComparison(
      await this.comparison.compare(roomId, userId, decisionId, dto.candidate_ids),
    );
  }

  // ── Voice ─────────────────────────────────────────────────────────────

  @Post(':id/candidates/:candidateId/vote')
  async vote(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('candidateId', ParseUUIDPipe) candidateId: string,
    @Body() dto: VoteDto,
  ) {
    await this.collaboration.vote(
      roomId,
      userId,
      candidateId,
      dto.value,
      dto.note,
    );
    const votes = await this.collaboration.votesFor(roomId, candidateId);
    return {
      votes: votes.map((vote) => ({
        member_id: vote.memberId,
        name: vote.member.displayName ?? vote.member.user.name,
        value: vote.value,
        note: vote.note,
      })),
    };
  }

  @Get(':id/comments')
  async comments(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Query() dto: ListCommentsDto,
  ) {
    await this.access.require(roomId, userId);
    const comments = await this.collaboration.comments(roomId, {
      candidateId: dto.candidate_id,
      decisionId: dto.decision_id,
      limit: dto.limit,
    });
    return comments.map(serializeComment);
  }

  @Post(':id/comments')
  @HttpCode(HttpStatus.CREATED)
  async comment(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Body() dto: CommentDto,
  ) {
    const comment = await this.collaboration.comment(roomId, userId, {
      body: dto.body,
      decisionId: dto.decision_id ?? null,
      candidateId: dto.candidate_id ?? null,
    });
    return { id: comment.id };
  }

  @Delete(':id/comments/:commentId')
  async removeComment(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
    @Param('commentId', ParseUUIDPipe) commentId: string,
  ) {
    await this.collaboration.removeComment(roomId, userId, commentId);
    return { deleted: true };
  }

  // ── Plan ──────────────────────────────────────────────────────────────

  /**
   * Draw the plan.
   *
   * Refuses a room with open decisions, and names them. This is the one route
   * that enforces the whole model: nothing can be bought that was not chosen.
   */
  @Post(':id/plan')
  @HttpCode(HttpStatus.CREATED)
  async draw(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
  ) {
    return serializePlan(await this.plans.draw(roomId, userId));
  }

  @Get(':id/plan')
  async plan(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) roomId: string,
  ) {
    const plan = await this.plans.current(roomId, userId);
    return plan ? serializePlan(plan) : null;
  }

  /** Move a line between now and later — the plan's own verb. */
  @Patch(':id/plan/:planId/items/:itemId/stage')
  async stage(
    @CurrentUser('id') userId: string,
    @Param('planId', ParseUUIDPipe) planId: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: SetStageDto,
  ) {
    return serializePlan(
      await this.plans.setStage(planId, userId, itemId, dto.stage),
    );
  }

  @Patch(':id/plan/:planId/items/:itemId/quantity')
  async planQuantity(
    @CurrentUser('id') userId: string,
    @Param('planId', ParseUUIDPipe) planId: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: SetPlanQuantityDto,
  ) {
    return serializePlan(
      await this.plans.setQuantity(planId, userId, itemId, dto.quantity),
    );
  }

  @Delete(':id/plan/:planId/items/:itemId')
  async removePlanItem(
    @CurrentUser('id') userId: string,
    @Param('planId', ParseUUIDPipe) planId: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
  ) {
    return serializePlan(await this.plans.removeItem(planId, userId, itemId));
  }

  /**
   * Buy the `NOW` stage.
   *
   * Goes straight to `CheckoutService.checkoutLines` with the plan's own lines.
   * Her cart is neither read nor emptied on the way, and the `LATER` stage stays
   * on the plan.
   */
  @Post(':id/plan/:planId/checkout')
  @HttpCode(HttpStatus.CREATED)
  async checkout(
    @CurrentUser('id') userId: string,
    @Param('planId', ParseUUIDPipe) planId: string,
    @Body() dto: CreateOrderDto,
  ) {
    return this.plans.checkoutPlan(planId, userId, dto);
  }

  /** The staging vocabulary, so the client need not hard-code it. */
  @Get('meta/stages')
  stages() {
    return { stages: Object.values(PurchaseStage) };
  }
}
