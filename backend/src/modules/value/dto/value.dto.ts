import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { ValueBenefitKind, ValuePillar } from '@prisma/client';

/**
 * Reem Value's request shapes.
 *
 * Note how few there are, and that none of them earns anything. There is no
 * "claim", no "redeem", no "convert" — a woman cannot ask this system for
 * standing, and the absence of a route that would let her is the API surface
 * agreeing with the design. The only thing she may do is take up a benefit her
 * standing already opened.
 */

export class ValueEventsDto {
  @IsOptional()
  @IsEnum(ValuePillar)
  pillar?: ValuePillar;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  @Type(() => Number)
  limit?: number;

  @IsOptional()
  @IsUUID()
  cursor?: string;
}

export class ClaimBenefitDto {
  @IsString()
  @MaxLength(64)
  benefit_key!: string;
}

export class UseGrantDto {
  @IsString()
  @MaxLength(32)
  used_on_type!: string;

  @IsUUID()
  used_on_id!: string;
}

// ── Administration ──────────────────────────────────────────────────────

export class DraftPolicyDto {
  /** Keyed by `ValuePillar`. Relative; normalised at read time. */
  @IsOptional()
  @IsObject()
  pillar_weights?: Record<string, number>;

  @IsOptional()
  @IsObject()
  pillar_scales?: Record<string, number>;

  @IsOptional()
  @IsObject()
  event_weights?: Record<string, number>;

  @IsOptional()
  @IsObject()
  daily_pillar_caps?: Record<string, number>;

  @IsOptional()
  @IsInt()
  @Min(30)
  @Max(3650)
  half_life_days?: number;

  @IsOptional()
  @IsInt()
  @Min(90)
  @Max(3650)
  horizon_days?: number;

  /**
   * Bounded at 6000 in the DTO as well as documented in the constants: a
   * ceiling above 60% of the scale would let money reach the top of any
   * sensible ladder, and an administrator who wants that should have to change
   * code rather than a form field.
   */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(6000)
  commerce_ceiling_bps?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  reliability_baseline?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20)
  min_evidence_per_pillar?: number;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  note?: string;
}

export class SimulatePolicyDto {
  @IsOptional()
  @IsInt()
  @Min(50)
  @Max(5000)
  @Type(() => Number)
  sample?: number;
}

export class UpsertValueBenefitDto {
  @IsString()
  @MaxLength(64)
  key!: string;

  @IsEnum(ValueBenefitKind)
  kind!: ValueBenefitKind;

  @IsString()
  @MaxLength(80)
  title!: string;

  @IsString()
  @MaxLength(80)
  title_ar!: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  description_ar?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  min_tier_key?: string;

  @IsOptional()
  @IsObject()
  config?: Record<string, unknown>;

  @IsOptional()
  @IsInt()
  @Min(1)
  per_user_quota?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  quota_period_days?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  total_budget?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  unit_cost_syp?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  grant_ttl_days?: number;

  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}

export class FreezeProfileDto {
  @IsString()
  @MaxLength(280)
  reason!: string;
}

export class GrantBenefitDto {
  @IsUUID()
  user_id!: string;

  @IsString()
  @MaxLength(64)
  benefit_key!: string;
}
