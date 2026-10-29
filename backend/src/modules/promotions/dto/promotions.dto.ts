import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsIn,
  IsInt,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { PromotionPlacement, PromotionStatus, StoreAdTier } from '@prisma/client';
import { AudienceSpec, EVERYONE } from '../ad-plans';

const upper = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.toUpperCase() : value;

/** Who a campaign is for. Absent means everyone. */
export class AudienceDto {
  @IsIn(['everyone', 'targeted'])
  type!: 'everyone' | 'targeted';

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(14)
  @IsString({ each: true })
  @MaxLength(60, { each: true })
  governorates?: string[];

  @IsOptional() @IsBoolean() followers?: boolean;
  @IsOptional() @IsBoolean() past_buyers?: boolean;
  @IsOptional() @IsBoolean() interested?: boolean;
  @IsOptional() @IsBoolean() new_shoppers?: boolean;
}

export function toAudience(dto?: AudienceDto): AudienceSpec {
  if (!dto || dto.type !== 'targeted') return EVERYONE;
  return {
    targeted: true,
    governorates: dto.governorates ?? [],
    followers: dto.followers ?? false,
    pastBuyers: dto.past_buyers ?? false,
    interested: dto.interested ?? false,
    newShoppers: dto.new_shoppers ?? false,
  };
}

export class CreatePromotionDto {
  @IsUUID()
  offer_id!: string;

  @Transform(upper)
  @IsEnum(PromotionPlacement)
  placement!: PromotionPlacement;

  /**
   * Optional: without it she pays the quoted price. With it, at least the
   * quote — paying more raises her share of the slot.
   */
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  fee?: number;

  @IsISO8601()
  starts_at!: string;

  @IsISO8601()
  ends_at!: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => AudienceDto)
  audience?: AudienceDto;

  /** FEED_TOP: which of her posts to pin. */
  @IsOptional()
  @IsUUID()
  content_id?: string;
}

export class SetPromotionStatusDto {
  @Transform(upper)
  @IsEnum(PromotionStatus)
  status!: PromotionStatus;
}

/** A campaign from «مركز الإعلانات»: a start and a number of days. */
export class CampaignDraftDto {
  @IsUUID()
  offer_id!: string;

  @Transform(upper)
  @IsEnum(PromotionPlacement)
  placement!: PromotionPlacement;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(30)
  days!: number;

  /** Defaults to now. */
  @IsOptional()
  @IsISO8601()
  starts_at?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => AudienceDto)
  audience?: AudienceDto;

  @IsOptional()
  @IsUUID()
  content_id?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  fee?: number;
}

export class LaunchCampaignDto extends CampaignDraftDto {
  /** Charge and go live now. False saves it unpaid, to launch later. */
  @IsOptional()
  @IsBoolean()
  launch?: boolean;
}

export class SubscribePlanDto {
  @Transform(upper)
  @IsEnum(StoreAdTier)
  tier!: StoreAdTier;
}
