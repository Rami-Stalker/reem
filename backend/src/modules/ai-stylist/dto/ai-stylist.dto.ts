import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
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
  ValidateNested,
} from 'class-validator';
import {
  AiStylistFeedback,
  AiStylistModality,
  AiStylistOutfitStatus,
  ModestyLevel,
  OutfitSlot,
  StylePersona,
} from '@prisma/client';

/**
 * The stylist's request shapes.
 *
 * Snake_case on the wire like the rest of this API, and validated hard: the
 * brief a client may push (`BriefInputDto`) is the same closed vocabulary the
 * extractor works in, so a filter chip in the app and a sentence typed into
 * the chat produce the identical structure.
 */

export class StartConversationDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  title?: string;

  /** Optional opening message, so "ask and send" is one round trip. */
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  message?: string;
}

export class SendStylistMessageDto {
  @IsString()
  @MaxLength(1000)
  content!: string;

  /**
   * Present so the voice and image modalities can be added without a contract
   * change. Only `TEXT` is produced today; the others are accepted and stored
   * against the turn, with the transcript or caption in `content`.
   */
  @IsOptional()
  @IsEnum(AiStylistModality)
  modality?: AiStylistModality;
}

export class SizesDto {
  @IsOptional()
  @IsString()
  @IsIn(['XS', 'S', 'M', 'L', 'XL', 'XXL'])
  clothing?: string;

  @IsOptional()
  @IsString()
  @MaxLength(3)
  shoes?: string;
}

/**
 * A brief supplied directly rather than typed.
 *
 * This is what the "بناء إطلالة" screen posts when she picks an occasion and a
 * budget from controls instead of writing a sentence. It runs through exactly
 * the same retrieval and ranking as a parsed message.
 */
export class BriefInputDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  occasion?: string;

  @IsOptional()
  @IsArray()
  @IsEnum(OutfitSlot, { each: true })
  slots?: OutfitSlot[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  category_slugs?: string[];

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  budget_min?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  budget_max?: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  colours?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  avoid_colours?: string[];

  @IsOptional()
  @ValidateNested()
  @Type(() => SizesDto)
  sizes?: SizesDto;

  @IsOptional()
  @IsEnum(ModestyLevel)
  modesty?: ModestyLevel;

  @IsOptional()
  @IsArray()
  @IsEnum(StylePersona, { each: true })
  personas?: StylePersona[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  materials?: string[];

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(99)
  recipient_age?: number;

  @IsOptional()
  @IsBoolean()
  for_self?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(365)
  deadline_days?: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  keywords?: string[];
}

export class BuildOutfitDto extends BriefInputDto {
  /** How many slots to fill. A look longer than five reads as a shopping list. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(2)
  @Max(6)
  max_pieces?: number;
}

export class RecommendationFeedbackDto {
  @IsEnum(AiStylistFeedback)
  feedback!: AiStylistFeedback;
}

export class OutfitStatusDto {
  @IsEnum(AiStylistOutfitStatus)
  status!: AiStylistOutfitStatus;
}

export class UpdatePreferencesDto {
  @IsOptional()
  @IsEnum(ModestyLevel)
  modesty?: ModestyLevel;

  @IsOptional()
  @IsArray()
  @IsEnum(StylePersona, { each: true })
  personas?: StylePersona[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  favourite_colours?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  avoided_colours?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  preferred_category_slugs?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  avoided_category_slugs?: string[];

  @IsOptional()
  @ValidateNested()
  @Type(() => SizesDto)
  sizes?: SizesDto;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  budget_min?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  budget_max?: number;
}

export class ListOutfitsDto {
  @IsOptional()
  @IsEnum(AiStylistOutfitStatus)
  status?: AiStylistOutfitStatus;
}

export class ConversationListDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit = 20;
}

export class RecommendationHistoryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit = 20;

  @IsOptional()
  @IsUUID()
  conversation_id?: string;
}
