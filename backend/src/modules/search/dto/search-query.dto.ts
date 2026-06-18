import { Type } from 'class-transformer';
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export const SEARCH_SORTS = [
  'newest',
  'popular',
  'best_selling',
  'price_asc',
  'price_desc',
  'rating',
] as const;
export type SearchSort = (typeof SEARCH_SORTS)[number];

export class SearchQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  q?: string;
}

export class ProductSearchDto extends PaginationDto {
  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsString()
  category?: string;

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
  @IsUUID()
  seller_id?: string;

  @IsOptional()
  @IsIn(SEARCH_SORTS)
  sort?: SearchSort;
}
