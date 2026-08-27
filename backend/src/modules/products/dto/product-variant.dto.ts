import {
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  IsUrl,
  Min,
  MinLength,
} from 'class-validator';

/**
 * A CANONICAL variant — an option combination of the product itself
 * ({size: M, color: red}). It carries no price and no stock: those differ per
 * seller and live on SellerOfferVariant.
 */
export class CreateVariantDto {
  @IsString()
  @MinLength(1)
  name!: string;

  /** Q34 P2 — the option axes: size, colour, shade, scent, volume. */
  @IsObject()
  attributes!: Record<string, unknown>;

  /** Q34 P2 — a different image per option. */
  @IsOptional()
  @IsUrl({ require_tld: false })
  image_url?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sort_order?: number;
}

export class UpdateVariantDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  name?: string;

  @IsOptional()
  @IsObject()
  attributes?: Record<string, unknown>;

  @IsOptional()
  @IsUrl({ require_tld: false })
  image_url?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sort_order?: number;
}
