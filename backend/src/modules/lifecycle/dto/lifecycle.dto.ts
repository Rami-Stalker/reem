import { Type } from 'class-transformer';
import { IsIn, IsInt, IsNumber, IsOptional, Max, Min } from 'class-validator';
import { LIFECYCLE_STAGES, LifecycleStage } from '../customer-segments';

export class LifecycleStageQueryDto {
  @IsIn(LIFECYCLE_STAGES as unknown as string[])
  stage!: LifecycleStage;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1000)
  limit = 100;
}

export class ReengagementRunDto {
  /**
   * Which lapsed group to reach. Only the two stages a win-back message is
   * appropriate for — sending "we missed you" to a woman who bought yesterday
   * is worse than sending nothing.
   */
  @IsOptional()
  @IsIn(['at_risk', 'lapsed'])
  stage?: 'at_risk' | 'lapsed';

  /**
   * Bounded low. There is no way to un-send a push notification, so a job
   * that could reach the whole customer base in one pass is one bad call away
   * from doing it.
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(2000)
  limit?: number;

  /**
   * Only reach customers projected to be worth at least this much.
   *
   * What makes a retention budget go where it earns. Spread evenly across
   * everyone who might leave, it is spent mostly on customers who were never
   * worth much.
   */
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  min_projected_value?: number;
}

export class ReengagementReportDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(365)
  days?: number;
}
