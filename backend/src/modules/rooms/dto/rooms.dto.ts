import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import {
  OutfitSlot,
  PurchaseStage,
  RoomKind,
  RoomMemberRole,
  RoomStatus,
} from '@prisma/client';

/**
 * Reem Rooms' request shapes.
 *
 * Read the verbs and the design is visible: `propose`, `choose`, `skip`,
 * `reject`, `stage`. Not one of them is `addToCart`. The vocabulary is the
 * feature — a room is a place where things are argued about and decided, and an
 * API whose only verb was "add" would have produced a cart however the tables
 * were shaped.
 */

// ── Rooms ───────────────────────────────────────────────────────────────

export class CreateRoomDto {
  @IsString()
  @MaxLength(80)
  title!: string;

  @IsOptional()
  @IsEnum(RoomKind)
  kind?: RoomKind;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  /** Lexicon occasion key — seeds the room's opening decisions. */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  occasion?: string;

  @IsOptional()
  @IsDateString()
  target_date?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  budget_min_syp?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  budget_max_syp?: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  recipient_name?: string;

  @IsOptional()
  @IsUUID()
  recipient_user_id?: string;

  /** A room its recipient must never be able to open. Enforced server-side. */
  @IsOptional()
  @IsBoolean()
  is_surprise?: boolean;

  /** Pass false to open an empty room even when an occasion is named. */
  @IsOptional()
  @IsBoolean()
  seed_from_occasion?: boolean;
}

export class UpdateRoomDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  occasion?: string;

  @IsOptional()
  @IsDateString()
  target_date?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  budget_min_syp?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  budget_max_syp?: number;

  @IsOptional()
  @IsEnum(RoomStatus)
  status?: RoomStatus;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  cover_url?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  recipient_name?: string;
}

export class ListRoomsDto {
  @IsOptional()
  @IsEnum(RoomStatus)
  status?: RoomStatus;

  @IsOptional()
  @IsEnum(RoomKind)
  kind?: RoomKind;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(60)
  @Type(() => Number)
  limit?: number;
}

// ── Membership ──────────────────────────────────────────────────────────

export class InviteMemberDto {
  @IsUUID()
  user_id!: string;

  /**
   * Never OWNER — a room has one, and the service refuses the rest. Listed
   * here so the client can offer the two roles that make sense.
   */
  @IsOptional()
  @IsEnum(RoomMemberRole)
  role?: RoomMemberRole;
}

export class SetMemberRoleDto {
  @IsEnum(RoomMemberRole)
  role!: RoomMemberRole;
}

export class ShareRoomDto {
  /** A link may only make advisors or viewers. Enforced server-side. */
  @IsOptional()
  @IsEnum(RoomMemberRole)
  role?: RoomMemberRole;
}

// ── Decisions ───────────────────────────────────────────────────────────

export class CreateDecisionDto {
  @IsString()
  @MaxLength(80)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;

  @IsOptional()
  @IsEnum(OutfitSlot)
  slot?: OutfitSlot;

  /** How many candidates this question resolves to. One, normally. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10)
  pick_count?: number;

  /** False for a nice-to-have that must never hold the room back. */
  @IsOptional()
  @IsBoolean()
  is_required?: boolean;
}

export class UpdateDecisionDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10)
  pick_count?: number;

  @IsOptional()
  @IsBoolean()
  is_required?: boolean;
}

export class ReorderDecisionsDto {
  @IsArray()
  @IsUUID('4', { each: true })
  decision_ids!: string[];
}

export class SkipDecisionDto {
  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

// ── Candidates ──────────────────────────────────────────────────────────

export class AddCandidateDto {
  /** An offer, not a product: a room can weigh two sellers of the same dress. */
  @IsUUID()
  offer_id!: string;

  @IsOptional()
  @IsUUID()
  offer_variant_id?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(99)
  quantity?: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

export class UpdateCandidateDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(99)
  quantity?: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  position?: number;
}

export class RejectCandidateDto {
  /** Why it lost. Kept, so the same suggestion does not come back next week. */
  @IsOptional()
  @IsString()
  @MaxLength(300)
  reason?: string;
}

// ── Voice ───────────────────────────────────────────────────────────────

export class VoteDto {
  /** +1, −1, or 0 to withdraw the opinion entirely. */
  @IsInt()
  @IsIn([-1, 0, 1])
  value!: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}

export class CommentDto {
  @IsString()
  @MaxLength(1000)
  body!: string;

  /** Exactly one of these two. Enforced server-side. */
  @IsOptional()
  @IsUUID()
  decision_id?: string;

  @IsOptional()
  @IsUUID()
  candidate_id?: string;
}

export class ListCommentsDto {
  @IsOptional()
  @IsUUID()
  decision_id?: string;

  @IsOptional()
  @IsUUID()
  candidate_id?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(200)
  @Type(() => Number)
  limit?: number;
}

// ── Plan ────────────────────────────────────────────────────────────────

export class SetStageDto {
  @IsEnum(PurchaseStage)
  stage!: PurchaseStage;
}

export class SetPlanQuantityDto {
  @IsInt()
  @Min(1)
  @Max(99)
  quantity!: number;
}

export class CompareDto {
  /**
   * Narrow to specific candidates — normally the two or three she has
   * shortlisted. Omitted, everything still in the running is compared.
   */
  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  candidate_ids?: string[];
}
