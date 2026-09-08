import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { FlashSaleStatus } from '@prisma/client';

export class CreateFlashSaleDto {
  @IsString()
  @MaxLength(120)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsISO8601()
  starts_at!: string;

  @IsISO8601()
  ends_at!: string;

  /**
   * Staff only: run the sale on a named boutique's behalf. A seller's own
   * sale is always her own — the service ignores this for her.
   */
  @IsOptional()
  @IsUUID()
  seller_id?: string;
}

export class AddFlashSaleItemDto {
  @IsUUID()
  offer_id!: string;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  sale_price!: number;

  /** Null or absent means every unit in stock may go at this price. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1_000_000)
  quantity_cap?: number;

  /**
   * Who absorbs the discount. Defaults to the seller, matching how a
   * seller-created coupon is treated — settlement reads this to decide
   * whether the cut comes off her commission base or off marketing.
   */
  @IsOptional()
  @IsBoolean()
  funded_by_seller?: boolean;
}

export class SetFlashSaleStatusDto {
  @IsEnum(FlashSaleStatus)
  status!: FlashSaleStatus;
}
