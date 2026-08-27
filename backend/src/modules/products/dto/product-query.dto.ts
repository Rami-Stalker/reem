import { Transform, Type } from 'class-transformer';
import {
  IsBooleanString,
  IsIn,
  IsInt,
  IsNumberString,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export const PUBLIC_PRODUCT_SORTS = [
  'newest',
  'price_asc',
  'price_desc',
  'rating',
  'popular',
] as const;

export type PublicProductSort = (typeof PUBLIC_PRODUCT_SORTS)[number];

/**
 * Query parameters for public catalog browsing.
 *
 * This class has to exist. The global `ValidationPipe` runs with
 * `whitelist: true` and `forbidNonWhitelisted: true`, which rejects any
 * property it has no metadata for — and metadata comes from decorated DTO
 * classes. These routes previously typed their query as a plain
 * `Record<string, string>`, so *every* documented filter (`?limit`, `?q`,
 * `?sort`, `?min_price`, …) came back as a 400 and pagination on the public
 * product list did not work at all.
 */
export class ProductQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;

  /** Free-text search over title, description and brand. */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  q?: string;

  @IsOptional()
  @IsIn(PUBLIC_PRODUCT_SORTS)
  sort?: PublicProductSort;

  @IsOptional()
  @IsUUID()
  brand_id?: string;

  /** Minimum average rating, 0–5. */
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  @Max(5)
  rating?: number;

  /**
   * Price bounds are matched against the SYP-normalised roll-up, so a basket of
   * sellers pricing in USD and SYP filters consistently. Sent as strings
   * because SYP figures run into the millions.
   */
  @IsOptional()
  @IsNumberString({ no_symbols: false })
  min_price?: string;

  @IsOptional()
  @IsNumberString({ no_symbols: false })
  max_price?: string;

  @IsOptional()
  @IsBooleanString()
  featured?: string;
}
