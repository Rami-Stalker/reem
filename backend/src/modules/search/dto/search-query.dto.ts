import { Type } from 'class-transformer';
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export const SEARCH_SORTS = [
  // How well the phrase matched, and the default whenever there is a phrase —
  // a customer who typed something wants the closest answer first, not the
  // newest listing that happens to contain the word.
  'relevance',
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

/** A tap on a search result: which phrase, which product. */
export class SearchClickDto {
  @IsString()
  @MaxLength(200)
  q!: string;

  @IsUUID()
  product_id!: string;
}
