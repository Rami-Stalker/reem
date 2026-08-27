import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class UpdateTransportRouteDto {
  /** Lower runs first. */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1000)
  priority?: number;

  @IsOptional()
  @IsBoolean()
  enabled?: boolean;

  /**
   * Millionths of a currency unit per day, or `null` for no cap. Micros
   * because a single SMS costs a fraction of a cent and a float would drift
   * over a month of accumulation.
   */
  @IsOptional()
  @IsInt()
  @Min(0)
  daily_budget_micros?: number | null;

  /** Clears a tripped breaker and zeroes today's spend. */
  @IsOptional()
  @IsBoolean()
  reset_breaker?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}
