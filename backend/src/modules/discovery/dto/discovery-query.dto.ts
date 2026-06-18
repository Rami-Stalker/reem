import { Type } from 'class-transformer';
import { IsIn, IsNumber, IsOptional, Max, Min } from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export const DISCOVERY_SORTS = [
  'newest',
  'popular',
  'best_selling',
  'price_asc',
  'price_desc',
  'rating',
] as const;
export type DiscoverySort = (typeof DISCOVERY_SORTS)[number];

export class DiscoveryQueryDto extends PaginationDto {
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  min_price?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  max_price?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(5)
  rating?: number;

  @IsOptional()
  @IsIn(DISCOVERY_SORTS)
  sort?: DiscoverySort;

  /** Stable cache signature for this query's filter set. */
  filterSignature(): string {
    return [
      this.min_price ?? '',
      this.max_price ?? '',
      this.rating ?? '',
      this.sort ?? '',
      this.page,
      this.limit,
    ].join('|');
  }
}
