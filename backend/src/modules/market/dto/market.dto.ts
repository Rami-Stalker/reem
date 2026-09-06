import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayNotEmpty,
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { DropAudience, DropStatus, ResaleCondition, ResaleStatus } from '@prisma/client';

/** How many rows a list endpoint may return. One rule, every list. */
export class MarketListDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;
}

// ── Drops ───────────────────────────────────────────────────────────────

export class CreateDropDto {
  @IsString()
  @MaxLength(120)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsEnum(DropAudience)
  audience!: DropAudience;

  @IsDateString()
  starts_at!: string;

  /**
   * When the invited may enter, ahead of everyone else. Only meaningful for an
   * `EARLY_ACCESS` drop, and validated in the service rather than here because
   * the rule is about two fields at once.
   */
  @IsOptional()
  @IsDateString()
  early_access_at?: string;

  @IsOptional()
  @IsDateString()
  ends_at?: string;

  @IsArray()
  @ArrayNotEmpty()
  @ArrayMaxSize(20)
  @IsUUID('4', { each: true })
  product_ids!: string[];
}

export class DropStatusDto {
  @IsEnum(DropStatus)
  status!: DropStatus;
}

export class BuildAudienceDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(10)
  @Max(2000)
  limit?: number;
}

// ── Bundles ─────────────────────────────────────────────────────────────

export class BundleListDto extends MarketListDto {
  /** Lexicon occasion key — `wedding`, `eid`, … */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  occasion?: string;
}

// ── Resale ──────────────────────────────────────────────────────────────

export class CreateResaleListingDto {
  @IsEnum(ResaleCondition)
  condition!: ResaleCondition;

  /**
   * Optional: when she does not name one, the suggested price from what she
   * paid is used, and the request is refused if neither is known rather than
   * inventing a number.
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  price_syp?: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class ResaleStatusDto {
  @IsEnum(ResaleStatus)
  status!: ResaleStatus;
}

export class ResaleMarketDto extends MarketListDto {
  @IsOptional()
  @IsString()
  @MaxLength(20)
  slot?: string;
}
