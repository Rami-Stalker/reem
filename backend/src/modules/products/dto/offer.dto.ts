import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsNumberString,
  IsOptional,
  IsUUID,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Currency, OfferStatus } from '@prisma/client';

/**
 * Money crosses the wire as a decimal STRING, never a JSON number: SYP prices
 * run into the millions and `JSON.parse` would quietly round them. The pairing
 * with an explicit currency is mandatory — there is no platform default price
 * currency, the seller chooses (Q45 P2).
 */
export class OfferVariantPriceDto {
  @IsUUID()
  variant_id!: string;

  @IsOptional()
  @IsNumberString({ no_symbols: false })
  price?: string;

  @IsInt()
  @Min(0)
  stock!: number;

  @IsOptional()
  sku?: string;
}

export class CreateOfferDto {
  @IsUUID()
  product_id!: string;

  @IsEnum(Currency)
  currency!: Currency;

  @IsNumberString({ no_symbols: false })
  price!: string;

  @IsOptional()
  @IsNumberString({ no_symbols: false })
  compare_at_price?: string;

  /** Q35 P2 — wholesale tier pricing; requires a minimum quantity. */
  @IsOptional()
  @IsNumberString({ no_symbols: false })
  wholesale_price?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  wholesale_min_qty?: number;

  @IsInt()
  @Min(0)
  stock!: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  min_order_qty?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  max_order_qty?: number;

  @IsOptional()
  sku?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(60)
  handling_days?: number;

  /** Q30 P2 — made-to-order goods (3D prints, flower arrangements). */
  @IsOptional()
  @IsBoolean()
  is_made_to_order?: boolean;

  @IsOptional()
  @IsBoolean()
  requires_deposit?: boolean;

  @IsOptional()
  @IsNumberString({ no_symbols: false })
  deposit_percent?: string;

  @IsOptional()
  @IsBoolean()
  accepts_returns?: boolean;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => OfferVariantPriceDto)
  variants?: OfferVariantPriceDto[];
}

export class UpdateOfferDto {
  @IsOptional()
  @IsEnum(Currency)
  currency?: Currency;

  @IsOptional()
  @IsNumberString({ no_symbols: false })
  price?: string;

  @IsOptional()
  @IsNumberString({ no_symbols: false })
  compare_at_price?: string;

  @IsOptional()
  @IsNumberString({ no_symbols: false })
  wholesale_price?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  wholesale_min_qty?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  stock?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  min_order_qty?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  max_order_qty?: number;

  @IsOptional()
  sku?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(60)
  handling_days?: number;

  @IsOptional()
  @IsBoolean()
  is_made_to_order?: boolean;

  @IsOptional()
  @IsBoolean()
  requires_deposit?: boolean;

  @IsOptional()
  @IsBoolean()
  accepts_returns?: boolean;

  @IsOptional()
  @IsEnum(OfferStatus)
  status?: OfferStatus;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => OfferVariantPriceDto)
  variants?: OfferVariantPriceDto[];
}

export class AdjustOfferStockDto {
  /** Positive to restock, negative to deduct. */
  @IsInt()
  delta!: number;

  @IsOptional()
  @IsUUID()
  variant_id?: string;
}
