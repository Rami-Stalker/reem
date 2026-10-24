import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsLatitude,
  IsLongitude,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  IsUUID,
  ValidateNested,
} from 'class-validator';
import { Currency, PaymentMethodType } from '@prisma/client';
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

  /** Q53 P2 — district and rural flag drive the shipping zone. */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  district?: string;

  @IsOptional()
  @IsBoolean()
  is_rural?: boolean;

  @IsString()
  @MinLength(4)
  @MaxLength(300)
  address_line!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  landmark?: string;

  /** The map pin, when she dropped one. Sent as a pair; half a pin is ignored. */
  @IsOptional()
  @Type(() => Number)
  @IsLatitude()
  latitude?: number | null;

  @IsOptional()
  @Type(() => Number)
  @IsLongitude()
  longitude?: number | null;
}

export class CreateOrderDto {
  /**
   * One of her saved addresses, instead of typing it again.
   *
   * When present the server reads the address itself rather than trusting a
   * copy the client sent alongside it — a client that can post both is a
   * client that can post a different address than the one it displayed.
   */
  @IsOptional()
  @IsUUID()
  address_id?: string;

  /**
   * A typed-in address. Optional only because [address_id] may stand in its
   * place; the service refuses a request carrying neither.
   */
  @IsOptional()
  @ValidateNested()
  @Type(() => ShippingDetailsDto)
  shipping?: ShippingDetailsDto;

  /** Q57 — keep what she just typed, so the next order is two taps. */
  @IsOptional()
  @IsBoolean()
  save_address?: boolean;

  @IsEnum(PaymentMethodType)
  payment_method!: PaymentMethodType;

  /** Q49 P1 — the customer may be charged in SYP or USD. */
  @IsOptional()
  @IsEnum(Currency)
  currency?: Currency;

  @IsOptional()
  @IsBoolean()
  is_express?: boolean;

  /** Q44 P1 — hide the customer's identity from the sellers. */
  @IsOptional()
  @IsBoolean()
  privacy_mask?: boolean;

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
