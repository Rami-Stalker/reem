import { IsNotEmpty, IsOptional, IsString, Matches, MaxLength } from 'class-validator';
import { PHONE_REGEX } from '../../../common/constants';

export class LoginDto {
  @IsString()
  @Matches(PHONE_REGEX, {
    message: 'phone must be a valid phone number (7–15 digits, optional +)',
  })
  phone!: string;

  @IsString()
  @IsNotEmpty()
  password!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  device_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  platform?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  app_version?: string;

  @IsOptional()
  @IsString()
  @MaxLength(256)
  device_fingerprint?: string;
}
