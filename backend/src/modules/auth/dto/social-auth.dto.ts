import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuthProvider } from '@prisma/client';

export class SocialAuthDto {
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(AuthProvider)
  provider!: AuthProvider;

  @IsOptional()
  @IsString()
  id_token?: string;

  @IsOptional()
  @IsString()
  @MaxLength(256)
  provider_user_id?: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(160)
  email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

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
