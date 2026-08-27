import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

/**
 * A saved delivery address, in the shape a Syrian delivery actually takes.
 *
 * `governorate` is required and `district` is not, because the governorate
 * decides whether a parcel can be delivered at all while the district only
 * refines the price (Q53). A landmark is optional in the schema and asked for
 * in the UI, since an address here is usually given by what it is near.
 */
export class AddressDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  label?: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  recipient_name!: string;

  @IsString()
  @MinLength(6)
  @MaxLength(20)
  recipient_phone!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(60)
  governorate!: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  district?: string;

  @IsString()
  @MinLength(2)
  @MaxLength(60)
  city!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(280)
  address_line!: string;

  @IsOptional()
  @IsString()
  @MaxLength(140)
  landmark?: string;

  /** Q53 P2 — the rural tier costs more and takes longer. */
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  is_rural?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  delivery_instructions?: string;

  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  is_default?: boolean;
}

/** Every field optional — she is correcting one line, not retyping the card. */
export class UpdateAddressDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  label?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  recipient_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  recipient_phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  governorate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  district?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  address_line?: string;

  @IsOptional()
  @IsString()
  @MaxLength(140)
  landmark?: string;

  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  is_rural?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  delivery_instructions?: string;

  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  is_default?: boolean;
}
