import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/**
 * Windows are bounded on purpose.
 *
 * Every one of these queries is a percentile over a date range, and an
 * unbounded `days` is an invitation to ask for five years of order history
 * from a phone. The ceilings are the longest window any of the screens can
 * actually draw.
 */

export class RadarQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(7)
  @Max(90)
  days?: number;
}

export class HealthQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(14)
  @Max(180)
  days?: number;
}

export class ProductHealthQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(7)
  @Max(90)
  days?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;
}

export class HealthHistoryQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(7)
  @Max(365)
  days?: number;
}
