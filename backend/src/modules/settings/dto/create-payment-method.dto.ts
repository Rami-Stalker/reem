import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
} from 'class-validator';

export class CreatePaymentMethodDto {
  @IsString()
  brand!: string;

  @IsString()
  @Length(4, 4)
  last4!: string;

  @IsInt()
  @Min(1)
  @Max(12)
  exp_month!: number;

  @IsInt()
  @Min(2000)
  @Max(2100)
  exp_year!: number;

  @IsOptional()
  @IsBoolean()
  is_default?: boolean;
}
