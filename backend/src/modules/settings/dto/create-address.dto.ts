import {
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateAddressDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  label: string = 'Home';

  @IsString()
  @MinLength(1)
  street!: string;

  @IsString()
  @MinLength(1)
  city!: string;

  @IsString()
  @MinLength(1)
  country!: string;

  @IsOptional()
  @IsString()
  postal_code?: string | null;

  @IsOptional()
  @IsBoolean()
  is_default?: boolean;
}
