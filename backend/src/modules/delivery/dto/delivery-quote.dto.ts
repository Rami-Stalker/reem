import {
  IsBoolean,
  IsEnum,
  IsNumberString,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';
import { Currency } from '@prisma/client';

export class DeliveryQuoteDto {
  @IsString()
  @MinLength(2)
  governorate!: string;

  /** Q53 P2 — city centre and rural are priced separately. */
  @IsOptional()
  @IsString()
  district?: string;

  @IsOptional()
  @IsBoolean()
  is_rural?: boolean;

  @IsOptional()
  @IsBoolean()
  is_express?: boolean;

  @IsOptional()
  @IsNumberString({ no_symbols: false })
  subtotal?: string;

  @IsOptional()
  @IsEnum(Currency)
  currency?: Currency;
}
