import { Transform, Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import {
  TrendAttributeDimension,
  TrendInsightStatus,
  TrendStage,
  TrendWindow,
  UnmetDemandStatus,
} from '@prisma/client';

/**
 * Query and body shapes for `/trends/*`.
 *
 * Snake_case on the wire, camelCase inside — the platform's contract, and the
 * `@Transform` on every enum is what lets a client send `d7` or `D7` without
 * either the app or the API having to care which.
 */

const upper = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.toUpperCase() : value;

/** Present on nearly every read: which look-back the caller wants. */
export class TrendWindowDto {
  @IsOptional()
  @Transform(upper)
  @IsEnum(TrendWindow)
  window: TrendWindow = TrendWindow.D7;
}

export class TrendListDto extends TrendWindowDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit = 25;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset = 0;
}

export class SellerProductTrendsDto extends TrendListDto {
  @IsOptional()
  @Transform(upper)
  @IsEnum(TrendStage)
  stage?: TrendStage;
}

export class AdminProductTrendsDto extends TrendListDto {
  @IsOptional()
  @Transform(upper)
  @IsEnum(TrendStage)
  stage?: TrendStage;

  @IsOptional()
  @IsUUID()
  category_id?: string;

  /**
   * Hides thinly-evidenced rows. A merchandiser scanning for something to act
   * on usually wants `0.3` and up; the default is 0 so the list is complete
   * unless she says otherwise.
   */
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  @Max(1)
  min_confidence?: number;
}

export class AttributeTrendsDto {
  @Transform(upper)
  @IsEnum(TrendAttributeDimension)
  dimension: TrendAttributeDimension = TrendAttributeDimension.COLOR;

  /** A category id to slice within, or omitted for the whole platform. */
  @IsOptional()
  @IsUUID()
  scope_id?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(90)
  days = 7;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 20;
}

export class ForecastQueryDto {
  /** Only the horizons the nightly run pre-computes are readable. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsEnum({ SEVEN: 7, FOURTEEN: 14, THIRTY: 30 })
  horizon_days = 14;
}

export class SearchTrendsDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(90)
  days = 30;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit = 50;

  /** Sort by growth instead of volume. */
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  rising = false;
}

export class UnmetDemandQueryDto {
  @IsOptional()
  @Transform(upper)
  @IsEnum(UnmetDemandStatus)
  status?: UnmetDemandStatus;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit = 50;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset = 0;
}

export class ReviewUnmetDemandDto {
  @Transform(upper)
  @IsEnum(UnmetDemandStatus)
  status!: UnmetDemandStatus;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class InsightFeedDto {
  @IsOptional()
  @IsArray()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.split(',').map((v) => v.trim().toUpperCase()) : value,
  )
  @IsEnum(TrendInsightStatus, { each: true })
  statuses?: TrendInsightStatus[];

  @IsOptional()
  @IsArray()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.split(',').map((v) => v.trim().toUpperCase()) : value,
  )
  @IsString({ each: true })
  kinds?: string[];

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 25;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset = 0;
}

export class UpdateInsightStatusDto {
  @Transform(upper)
  @IsEnum(TrendInsightStatus)
  status!: TrendInsightStatus;
}

export class SellerPerformanceDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(90)
  days = 30;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit = 25;
}

/**
 * The manual re-run an operator triggers from the ops panel.
 *
 * `lookback_days` is capped at thirty rather than left open: a backfill over a
 * year of history is a real thing to want, but it is a job to be scheduled and
 * watched, not something a dashboard button should be able to start inside a
 * request.
 */
export class RecomputeDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(30)
  lookback_days = 3;

  /** Skip the stages that are expensive and rarely the reason for a re-run. */
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  rollup_only = false;
}
