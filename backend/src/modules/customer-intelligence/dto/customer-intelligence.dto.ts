import { Type } from 'class-transformer';
import { IsIn, IsInt, IsNumber, IsOptional, Max, Min } from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export class CustomerBandQueryDto extends PaginationDto {
  @IsIn(['churn', 'propensity'])
  dimension!: 'churn' | 'propensity';

  @IsIn(['safe', 'watch', 'leaving', 'gone', 'cold', 'warm', 'hot'])
  band!: string;

  /**
   * Only customers projected to be worth at least this much.
   *
   * The filter that makes a churn list actionable: a retention budget spent
   * evenly across everybody who might leave is a budget spent mostly on
   * customers who were never worth much.
   */
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  min_value?: number;
}

export class CustomerSweepDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(365)
  since_days? = 7;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(20000)
  limit? = 2000;
}
