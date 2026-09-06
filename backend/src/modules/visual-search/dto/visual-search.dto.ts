import { AiStylistFeedback, VisualSearchSource } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/**
 * The multipart fields that travel beside the photograph.
 *
 * Everything here is optional and none of it changes what the pipeline does —
 * `source` is recorded for analytics, because knowing that four searches in
 * five are screenshots is what tells the team where to spend the next week.
 * The bytes decide everything that matters.
 */
export class StartVisualSearchDto {
  @IsOptional()
  @IsEnum(VisualSearchSource)
  source?: VisualSearchSource;

  /**
   * A sentence typed *with* the upload — "بدي شي شبه هيك بس أرخص".
   *
   * Folded on as a refinement immediately after the first search, using the
   * same code path a later sentence takes. One request for her, one behaviour
   * on the server.
   */
  @IsOptional()
  @IsString()
  @MaxLength(400)
  note?: string;
}

export class RefineVisualSearchDto {
  @IsString()
  @MinLength(2)
  @MaxLength(400)
  text!: string;
}

export class VisualSessionListDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number = 20;
}

export class VisualFeedbackDto {
  @IsEnum(AiStylistFeedback)
  feedback!: AiStylistFeedback;
}

export class SimilarProductsDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(24)
  limit?: number = 8;

  /** The stylist's "same look, less money" case. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  max_price?: number;

  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  same_category?: boolean;
}

/**
 * A try-on request.
 *
 * `consent` is required and must be true. It is not a default, not a profile
 * setting, and not inferred from her having uploaded a photograph — a client
 * that forgets to ask gets a 400 rather than an implicit yes.
 */
export class TryOnRequestDto {
  @IsUUID()
  product_id!: string;

  @IsOptional()
  @IsUUID()
  variant_id?: string;

  @IsOptional()
  @IsUUID()
  offer_id?: string;

  @IsOptional()
  @IsUUID()
  session_id?: string;

  @Type(() => Boolean)
  @IsBoolean()
  consent!: boolean;
}
