import { Transform } from 'class-transformer';
import { IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { OtpChannel, OtpPurpose } from '@prisma/client';
import { foldDigits, PhoneField } from '../../../common/phone/phone';

export class RequestOtpDto {
  @PhoneField()
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

  /**
   * Opaque per-request value from the app instance. Stored hashed, so a later
   * step can prove the code was verified by the same install that asked for
   * it — the second half of the anti-relay defence that `match_code` starts.
   */
  @IsOptional()
  @IsString()
  @MaxLength(128)
  client_nonce?: string;
}

export class VerifyOtpDto {
  @PhoneField()
  phone!: string;

  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(OtpPurpose)
  purpose!: OtpPurpose;

  /**
   * Absent on the reverse rail, where she sent the code rather than received
   * it. `OtpService.verifyAny` refuses an absent code when no reverse ceremony
   * is outstanding, so this stays a required field in every flow that has one.
   */
  @IsOptional()
  // Codes are typed on an Arabic keyboard as often as a Latin one.
  @Transform(({ value }) =>
    typeof value === 'string' ? foldDigits(value).trim() : value,
  )
  @IsString()
  @MinLength(4)
  @MaxLength(8)
  code?: string;
}

/**
 * Deliberately NOT `extends VerifyOtpDto`.
 *
 * It used to, which inherited a required `purpose` field. The client never
 * sent it — and could not sensibly send it, since the server hardcodes
 * `PASSWORD_RESET` — so every reset attempt died in the ValidationPipe with a
 * raw class-validator message. The last step of the only account-recovery
 * journey in the product was unreachable.
 */
export class ResetPasswordDto {
  @PhoneField()
  phone!: string;

  /** Absent on the reverse rail — see `VerifyOtpDto.code`. */
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? foldDigits(value).trim() : value,
  )
  @IsString()
  @MinLength(4)
  @MaxLength(8)
  code?: string;

  @IsString()
  @MinLength(8)
  @MaxLength(128)
  new_password!: string;
}
