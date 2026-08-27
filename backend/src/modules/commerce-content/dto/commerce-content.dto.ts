import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsISO8601,
  IsInt,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import {
  CommerceContentAnalyticsEventType,
  CommerceContentModerationStatus,
  CommerceContentPublicationChannel,
  CommerceContentStatus,
  CommerceContentVisibility,
  MediaType,
} from '@prisma/client';
import { PaginationDto } from '../../../common/dto/pagination.dto';
import { enumArray, enumValue } from './enum-transforms';
import { MediaUrlField } from '../../../common/dto/media-url.decorator';

export class CommerceContentMediaInputDto {
  @MediaUrlField()
  url!: string;

  @IsOptional()
  @IsEnum(MediaType)
  type?: MediaType;

  @IsOptional()
  @MediaUrlField()
  thumbnail_url?: string;

  @IsOptional()
  @MediaUrlField()
  streaming_url?: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  alt_text?: string;

  @IsOptional()
  @IsString()
  @MaxLength(180)
  blur_hash?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  duration_ms?: number;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;

  @IsOptional()
  @IsInt()
  @Min(0)
  sort_order?: number;
}

export class CommerceContentProductTagInputDto {
  @IsUUID()
  product_id!: string;

  @IsOptional()
  @IsUUID()
  variant_id?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  role?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  display_label?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  x?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  y?: number;

  @IsOptional()
  @IsUrl()
  target_url?: string;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;

  @IsOptional()
  @IsInt()
  @Min(0)
  sort_order?: number;
}

export class CreateCommerceContentDto {
  @IsString()
  @Matches(/^[a-z][a-z0-9_:-]{2,63}$/)
  content_type!: string;

  @IsOptional()
  @IsString()
  @MaxLength(180)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(10_000)
  body?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[a-z]{2}(-[A-Z]{2})?$/)
  locale?: string;

  @IsOptional()
  @Transform(({ value }) => enumValue(value))
  @IsEnum(CommerceContentVisibility)
  visibility?: CommerceContentVisibility;

  @IsObject()
  payload!: Record<string, unknown>;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;

  @IsOptional()
  @Transform(({ value }) => enumArray(value))
  @IsArray()
  @ArrayMaxSize(12)
  @IsEnum(CommerceContentPublicationChannel, { each: true })
  publication_targets?: CommerceContentPublicationChannel[];

  @IsOptional()
  @IsISO8601()
  scheduled_at?: string;

  @IsOptional()
  @IsISO8601()
  expires_at?: string;

  @IsOptional()
  @IsISO8601()
  pinned_until?: string;

  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => CommerceContentMediaInputDto)
  @ArrayMaxSize(20)
  media?: CommerceContentMediaInputDto[];

  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => CommerceContentProductTagInputDto)
  @ArrayMaxSize(80)
  product_tags?: CommerceContentProductTagInputDto[];
}

export class UpdateCommerceContentDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(180)
  title?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(10_000)
  body?: string | null;

  @IsOptional()
  @IsString()
  @Matches(/^[a-z]{2}(-[A-Z]{2})?$/)
  locale?: string;

  @IsOptional()
  @Transform(({ value }) => enumValue(value))
  @IsEnum(CommerceContentVisibility)
  visibility?: CommerceContentVisibility;

  @IsOptional()
  @IsObject()
  payload?: Record<string, unknown>;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown> | null;

  @IsOptional()
  @Transform(({ value }) => enumArray(value))
  @IsArray()
  @ArrayMaxSize(12)
  @IsEnum(CommerceContentPublicationChannel, { each: true })
  publication_targets?: CommerceContentPublicationChannel[];

  @IsOptional()
  @IsISO8601()
  scheduled_at?: string | null;

  @IsOptional()
  @IsISO8601()
  expires_at?: string | null;

  @IsOptional()
  @IsISO8601()
  pinned_until?: string | null;

  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => CommerceContentMediaInputDto)
  @ArrayMaxSize(20)
  media?: CommerceContentMediaInputDto[];

  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => CommerceContentProductTagInputDto)
  @ArrayMaxSize(80)
  product_tags?: CommerceContentProductTagInputDto[];

  @IsOptional()
  @IsString()
  @MaxLength(280)
  change_note?: string;
}

export class SellerContentQueryDto extends PaginationDto {
  @IsOptional()
  @Transform(({ value }) => enumValue(value))
  @IsEnum(CommerceContentStatus)
  status?: CommerceContentStatus;

  @IsOptional()
  @IsString()
  @Matches(/^[a-z][a-z0-9_:-]{2,63}$/)
  content_type?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  q?: string;
}

export class CommerceFeedQueryDto extends PaginationDto {
  @IsOptional()
  @Transform(({ value }) => enumValue(value))
  @IsEnum(CommerceContentPublicationChannel)
  channel?: CommerceContentPublicationChannel;

  @IsOptional()
  @IsString()
  @Matches(/^[a-z][a-z0-9_:-]{2,63}$/)
  content_type?: string;

  @IsOptional()
  @IsUUID()
  seller_id?: string;
}

export class RecordCommerceContentEventDto {
  @Transform(({ value }) => enumValue(value))
  @IsEnum(CommerceContentAnalyticsEventType)
  type!: CommerceContentAnalyticsEventType;

  @IsOptional()
  @IsUUID()
  product_id?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  value?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  watch_time_ms?: number;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

export class ModerateCommerceContentDto {
  @Transform(({ value }) => enumValue(value))
  @IsEnum(CommerceContentModerationStatus)
  status!: CommerceContentModerationStatus;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}
