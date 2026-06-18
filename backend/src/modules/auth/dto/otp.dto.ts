import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { OtpChannel, OtpPurpose } from '@prisma/client';
import { PHONE_REGEX } from '../../../common/constants';

export class RequestOtpDto {
  @IsString()
  @Matches(PHONE_REGEX, {
    message: 'phone must be a valid phone number (7-15 digits, optional +)',
  })
  phone!: string;

  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(OtpPurpose)
  purpose!: OtpPurpose;

  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(OtpChannel)
  channel?: OtpChannel;
}

export class VerifyOtpDto {
  @IsString()
  @Matches(PHONE_REGEX, {
    message: 'phone must be a valid phone number (7-15 digits, optional +)',
  })
  phone!: string;

  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(OtpPurpose)
  purpose!: OtpPurpose;

  @IsString()
  @MinLength(4)
  @MaxLength(8)
  code!: string;
}

export class ResetPasswordDto extends VerifyOtpDto {
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  new_password!: string;
}
