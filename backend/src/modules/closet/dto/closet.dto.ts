import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import {
  ClosetItemStatus,
  ClosetSeason,
  ModestyLevel,
  OutfitSlot,
} from '@prisma/client';

/**
 * The closet's request shapes.
 *
 * Snake_case on the wire like the rest of this API. The descriptor fields
 * repeat across three DTOs rather than being inherited, because each one means
 * something slightly different: on `AddCatalogItemDto` they *correct* a
 * derivation, on `AddPersonalItemDto` they *are* the derivation, and on
 * `UpdateClosetItemDto` an absent field means "leave it" where an empty array
 * means "none". A shared base class would have hidden that third distinction,
 * which is the one that actually bites.
 */

// ── Items ───────────────────────────────────────────────────────────────

export class DescriptorDto {
  @IsOptional()
  @IsEnum(OutfitSlot)
  slot?: OutfitSlot;

  /** Lexicon colour keys. Unknown ones are dropped, not rejected. */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(40, { each: true })
  colours?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(40, { each: true })
  materials?: string[];

  @IsOptional()
  @IsEnum(ModestyLevel)
  modesty?: ModestyLevel;

  @IsOptional()
  @IsArray()
  @IsEnum(ClosetSeason, { each: true })
  seasons?: ClosetSeason[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(40, { each: true })
  occasions?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(16)
  size?: string;
}

export class AddCatalogItemDto {
  @IsUUID()
  product_id!: string;

  @IsOptional()
  @IsUUID()
  offer_id?: string;

  @IsOptional()
  @IsUUID()
  variant_id?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsDateString()
  acquired_at?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => DescriptorDto)
  descriptor?: DescriptorDto;
}

export class AddPersonalItemDto {
  @IsString()
  @MaxLength(120)
  title!: string;

  /**
   * Required, unlike everywhere else a descriptor appears. A photograph has no
   * category to fall back on, and a piece filed in the wrong slot distorts every
   * gap and every outfit it touches — see `ClosetItemService.addPersonal`.
   */
  @IsEnum(OutfitSlot)
  slot!: OutfitSlot;

  /** A claimed upload, purpose `closet`. */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  image_url?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  brand_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsDateString()
  acquired_at?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  purchase_price_syp?: number;

  @IsOptional()
  @ValidateNested()
  @Type(() => DescriptorDto)
  descriptor?: DescriptorDto;
}

export class UpdateClosetItemDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  image_url?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  brand_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsBoolean()
  is_favourite?: boolean;

  @IsOptional()
  @IsDateString()
  acquired_at?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  purchase_price_syp?: number;

  @IsOptional()
  @ValidateNested()
  @Type(() => DescriptorDto)
  descriptor?: DescriptorDto;
}

export class ClosetItemStatusDto {
  @IsEnum(ClosetItemStatus)
  status!: ClosetItemStatus;
}

export class ListClosetItemsDto {
  @IsOptional()
  @IsEnum(OutfitSlot)
  slot?: OutfitSlot;

  @IsOptional()
  @IsEnum(ClosetItemStatus)
  status?: ClosetItemStatus;

  @IsOptional()
  @IsEnum(ClosetSeason)
  season?: ClosetSeason;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  occasion?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  colour?: string;

  @IsOptional()
  @IsBoolean()
  @Type(() => Boolean)
  favourites_only?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  search?: string;

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

export class LogWearDto {
  /** Defaults to today. Normalised to midnight UTC before it is stored. */
  @IsOptional()
  @IsDateString()
  worn_on?: string;
}

// ── Looks ───────────────────────────────────────────────────────────────

export class LookSlotDto {
  @IsEnum(OutfitSlot)
  slot!: OutfitSlot;

  /** Exactly one of these two. Enforced in the service, in Arabic. */
  @IsOptional()
  @IsUUID()
  closet_item_id?: string;

  @IsOptional()
  @IsUUID()
  product_id?: string;

  @IsOptional()
  @IsUUID()
  offer_id?: string;

  @IsOptional()
  @IsUUID()
  variant_id?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}

export class CreateLookDto {
  @IsString()
  @MaxLength(80)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  occasion?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsArray()
  @IsEnum(ClosetSeason, { each: true })
  seasons?: ClosetSeason[];

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => LookSlotDto)
  items?: LookSlotDto[];
}

export class UpdateLookDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  occasion?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsArray()
  @IsEnum(ClosetSeason, { each: true })
  seasons?: ClosetSeason[];

  @IsOptional()
  @IsBoolean()
  is_favourite?: boolean;

  @IsOptional()
  @IsBoolean()
  is_archived?: boolean;
}

export class SetLookItemsDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => LookSlotDto)
  items!: LookSlotDto[];
}

export class LogLookWearDto {
  @IsOptional()
  @IsDateString()
  worn_on?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  occasion_note?: string;
}

export class ListLooksDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  occasion?: string;

  @IsOptional()
  @IsBoolean()
  @Type(() => Boolean)
  include_archived?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  @Type(() => Number)
  limit?: number;
}

// ── Today, gaps, settings ───────────────────────────────────────────────

export class TodayDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  occasion?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(12)
  @Type(() => Number)
  limit?: number;
}

export class GapSuggestionsDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(24)
  @Type(() => Number)
  limit?: number;
}

export class ClosetSettingsDto {
  @IsOptional()
  @IsBoolean()
  auto_add_purchases?: boolean;

  @IsOptional()
  @IsBoolean()
  suggestions_enabled?: boolean;
}

export class BackfillDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  @Type(() => Number)
  limit?: number;
}
