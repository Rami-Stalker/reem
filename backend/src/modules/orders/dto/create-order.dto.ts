import { Type } from 'class-transformer';
import {
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { PaymentMethodType } from '@prisma/client';
import { PHONE_REGEX } from '../../../common/constants';

export class ShippingDetailsDto {
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  recipient_name!: string;

  @IsString()
  @Matches(PHONE_REGEX, { message: 'recipient_phone must be a valid phone number' })
  recipient_phone!: string;

  @IsString()
  @MinLength(2)
  governorate!: string;

  @IsString()
  @MinLength(2)
  city!: string;

  @IsString()
  @MinLength(4)
  @MaxLength(300)
  address_line!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  landmark?: string;
}

export class CreateOrderDto {
  @ValidateNested()
  @Type(() => ShippingDetailsDto)
  @IsNotEmpty()
  shipping!: ShippingDetailsDto;

  @IsEnum(PaymentMethodType)
  payment_method!: PaymentMethodType;

  @IsOptional()
  @IsString()
  coupon_code?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  delivery_instructions?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}
