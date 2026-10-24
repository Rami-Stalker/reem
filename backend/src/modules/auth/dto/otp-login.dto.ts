import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { OtpChannel, OtpPurpose } from '@prisma/client';
import { foldDigits, PhoneField } from '../../../common/phone/phone';

/**
 * Device descriptors every entry point accepts, so a session can be named
 * something a person recognises in her device list.
 */
export class DeviceDescriptorDto {
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

/**
 * Step one of the only sign-in journey most Ohara accounts will ever use: she
 * types her number.
 *
 * The response is identical whether or not that number has an account, which
 * is not a nicety on a women-only platform — a route that answers "yes, she is
 * on Ohara" to anybody who asks is a route that answers it to her family.
 */
export class StartOtpLoginDto extends DeviceDescriptorDto {
  @PhoneField()
  phone!: string;

  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(OtpChannel)
  channel?: OtpChannel;

  /**
   * Per-attempt random value from this app install. Stored hashed with the
   * challenge and demanded back at verification, so a code recited over the
   * phone to somebody else cannot be spent from their handset.
   */
  @IsOptional()
  @IsString()
  @MaxLength(128)
  client_nonce?: string;
}

/** Step two: the code. Either signs her in, or hands back a ticket to sign up. */
export class CompleteOtpLoginDto extends DeviceDescriptorDto {
  @PhoneField()
  phone!: string;

  @Transform(({ value }) =>
    typeof value === 'string' ? foldDigits(value).trim() : value,
  )
  @IsString()
  @MinLength(4)
  @MaxLength(8)
  code!: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  client_nonce?: string;
}

/**
 * Step two on the reverse rail. Deliberately has no `code` field.
 *
 * There is nothing for her to type: she sent `VERIFY …` from her own handset
 * and the provider matched the sender against the number she claimed. Giving
 * this route a code field would invite a client to send one and a reader to
 * believe it mattered.
 */
export class CompleteReverseOtpLoginDto extends DeviceDescriptorDto {
  @PhoneField()
  phone!: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  client_nonce?: string;
}

/**
 * The client's poll while she is away in her messaging app.
 *
 * Read-only and cheap by design — it reports where the ceremony stands and
 * spends nothing, so a client may call it on a timer without eating the
 * attempt budget that protects a code.
 */
export class ReverseOtpStatusDto {
  @PhoneField()
  phone!: string;

  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(OtpPurpose)
  purpose!: OtpPurpose;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  client_nonce?: string;
}
