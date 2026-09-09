import {
  IsBoolean,
  IsDateString,
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
  MinLength,
} from 'class-validator';
import {
  Currency,
  CouponType,
  LoyaltyRewardType,
  MembershipTierStatus,
  ReferralParticipantType,
} from '@prisma/client';

export class CreateCouponDto {
  @IsString()
  @MinLength(3)
  @MaxLength(32)
  code!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  title!: string;

  @IsEnum(CouponType)
  type!: CouponType;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  discount_percent?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  amount_off?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  min_order_amount?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  max_uses?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  per_user_limit?: number;

  /**
   * Who pays for the discount, and — from now on — whose goods it covers.
   *
   * `funded_by_seller` recorded that a seller paid without recording *which*
   * seller's items it applied to, so checkout reduced every seller's
   * commission base in the basket and one boutique funded another's promotion.
   * Setting `seller_id` scopes the code to her lines alone. It is validated
   * against a real seller account, so a typo becomes a refusal rather than a
   * code that silently covers nothing.
   */
  @IsOptional()
  @IsUUID()
  seller_id?: string;

  /** Only lines in this category. Matched on the line's own category. */
  @IsOptional()
  @IsUUID()
  category_id?: string;

  /** Only this product — the narrowest scope there is. */
  @IsOptional()
  @IsUUID()
  product_id?: string;

  /** Set for a user-specific coupon; omit for a global coupon. */
  @IsOptional()
  @IsUUID()
  user_id?: string;

  @IsDateString()
  expires_at!: string;

  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}

export class UpdateCouponDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(120) title?: string;
  @IsOptional() @IsEnum(CouponType) type?: CouponType;
  @IsOptional() @IsNumber() @Min(0) @Max(100) discount_percent?: number;
  @IsOptional() @IsNumber() @Min(0) amount_off?: number;
  @IsOptional() @IsNumber() @Min(0) min_order_amount?: number;
  @IsOptional() @IsInt() @Min(1) max_uses?: number;
  /**
   * Scope, narrowable after issue. `null` clears it — an operator who scoped a
   * code to the wrong boutique needs a way back to "the whole basket" without
   * deleting a code customers may already be holding.
   */
  @IsOptional() @IsUUID() seller_id?: string | null;
  @IsOptional() @IsUUID() category_id?: string | null;
  @IsOptional() @IsUUID() product_id?: string | null;
  @IsOptional() @IsInt() @Min(1) per_user_limit?: number;
  @IsOptional() @IsDateString() expires_at?: string;
  @IsOptional() @IsBoolean() is_active?: boolean;
}

export class ValidateCouponDto {
  @IsString()
  @MinLength(3)
  code!: string;

  @IsNumber()
  @Min(0)
  subtotal!: number;

  /** The basket's currency — a discount is meaningless without it. */
  @IsOptional()
  @IsEnum(Currency)
  currency?: Currency;
}

export class RedeemPointsDto {
  @IsInt()
  @Min(100)
  points!: number;
}

export class CreateReferralCodeDto {
  @IsOptional()
  @IsEnum(ReferralParticipantType)
  participant_type?: ReferralParticipantType;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  campaign?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  max_uses?: number;

  @IsOptional()
  @IsDateString()
  expires_at?: string;
}

export class ApplyReferralCodeDto {
  @IsString()
  @MinLength(4)
  @MaxLength(24)
  code!: string;

  @IsOptional()
  @IsEnum(ReferralParticipantType)
  participant_type?: ReferralParticipantType;
}

export class CreateMembershipTierDto {
  @IsString()
  @MinLength(2)
  @MaxLength(40)
  key!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  name!: string;

  @IsInt()
  @Min(0)
  min_lifetime_points!: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(10)
  points_multiplier?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10000)
  cashback_bps?: number;

  @IsOptional()
  @IsBoolean()
  free_shipping?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  priority?: number;

  @IsOptional()
  @IsEnum(MembershipTierStatus)
  status?: MembershipTierStatus;

  @IsOptional()
  @IsObject()
  benefits?: Record<string, unknown>;
}

export class UpsertLoyaltyRewardDto {
  @IsOptional()
  @IsUUID()
  id?: string;

  @IsOptional()
  @IsUUID()
  tier_id?: string;

  @IsEnum(LoyaltyRewardType)
  type!: LoyaltyRewardType;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  description?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  points_cost?: number;

  @IsOptional()
  @IsUUID()
  coupon_id?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  cashback_amount?: number;

  @IsOptional()
  @IsBoolean()
  exclusive?: boolean;

  @IsOptional()
  @IsBoolean()
  is_active?: boolean;

  @IsOptional()
  @IsDateString()
  starts_at?: string;

  @IsOptional()
  @IsDateString()
  ends_at?: string;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

export class RedeemCashbackDto {
  @IsOptional()
  @IsNumber()
  @Min(0)
  amount?: number;
}
