import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { ProductMediaDto } from './product-media.dto';
import { CreateVariantDto } from './product-variant.dto';
import { CreateOfferDto } from './offer.dto';

/**
 * The offer half of a "list something new" request — same as CreateOfferDto
 * minus `product_id`, because the product is being created in the same call.
 */
export class InlineOfferDto extends CreateOfferDto {
  @IsOptional()
  @IsUUID()
  declare product_id: string;
}

/**
 * Creating a CANONICAL catalog entry plus the seller's first offer on it.
 *
 * A seller who wants to sell something already in the catalog should not come
 * through here — they post an offer against the existing product instead, which
 * is what makes cross-seller price comparison possible (Q23 P2).
 */
export class CreateProductDto {
  @IsString()
  @MinLength(2)
  @MaxLength(140)
  title!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  description!: string;

  /** Must be a LEAF category (level 2) — enforced in the service (Q26 P2). */
  @IsUUID()
  category_id!: string;

  @IsOptional()
  @IsUUID()
  brand_id?: string;

  /** Validated against the category's attribute schema (Q27 P2). */
  @IsOptional()
  @IsObject()
  attributes?: Record<string, unknown>;

  /** Barcode — optional, but unique across the catalog when present (Q24 P2). */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  gtin?: string;

  /** Q28 P2 — at most ten images per product. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => ProductMediaDto)
  media?: ProductMediaDto[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => CreateVariantDto)
  variants?: CreateVariantDto[];

  @ValidateNested()
  @Type(() => InlineOfferDto)
  offer!: InlineOfferDto;
}
