import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { DeviceKeyStorage } from '@prisma/client';

export class RegisterDeviceKeyDto {
  /** Raw Ed25519 public key, base64url — 32 bytes, so 43 characters. */
  @IsString()
  @Matches(/^[A-Za-z0-9_-]{43}$/, {
    message: 'public_key must be a base64url-encoded 32-byte Ed25519 key',
  })
  public_key!: string;

  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(DeviceKeyStorage)
  key_storage?: DeviceKeyStorage;

  @IsOptional()
  @IsBoolean()
  hardware_backed?: boolean;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  label?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  platform?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  os_version?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  model?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  app_version?: string;
}

export class RenameDeviceKeyDto {
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  label!: string;
}
