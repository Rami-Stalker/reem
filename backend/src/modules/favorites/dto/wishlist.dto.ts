import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { WishlistItemType, WishlistShareVisibility } from '@prisma/client';

export class CreateWishlistCollectionDto {
  @IsString()
  @MaxLength(80)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(WishlistShareVisibility)
  visibility?: WishlistShareVisibility;
}

export class AddWishlistItemDto {
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(WishlistItemType)
  type!: WishlistItemType;

  @IsOptional()
  @IsUUID()
  product_id?: string;

  @IsOptional()
  @IsUUID()
  seller_id?: string;

  @IsOptional()
  @IsUUID()
  post_id?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  note?: string;

  @IsOptional()
  @IsBoolean()
  notify_price_drop?: boolean;

  @IsOptional()
  @IsBoolean()
  notify_back_in_stock?: boolean;
}

export class ShareWishlistDto {
  @IsOptional()
  @IsISO8601()
  expires_at?: string;
}
