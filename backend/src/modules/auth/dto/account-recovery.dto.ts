import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { AccountRecoveryStatus } from '@prisma/client';
import { foldDigits, PhoneField } from '../../../common/phone/phone';

/**
 * Opening a recovery case.
 *
 * Every answer is optional and every answer is about something **the platform
 * already holds** — owner decision 4. There is deliberately no field for a
 * selfie, an identity document or a photograph of anything: on this platform
 * that queue would be a bigger liability than the fraud it is meant to stop,
 * and the documents would answer the wrong question anyway.
 *
 * Answering nothing is allowed. It simply produces a case that scores zero and
 * that no reviewer should approve.
 */
export class SubmitRecoveryCaseDto {
  /** The number on the account she has lost. */
  @PhoneField()
  claimed_phone!: string;

  /** A number she can be reached on now, and the one the account moves to. */
  @PhoneField()
  contact_phone!: string;

  /**
   * A code just delivered to `contact_phone`. Verified before the case is
   * written, so the review queue only ever holds cases from someone reachable.
   */
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? foldDigits(value).trim() : value,
  )
  @IsString()
  @MinLength(4)
  @MaxLength(8)
  contact_code?: string;

  /** `YYYY-MM` — roughly when she joined. */
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? foldDigits(value).trim() : value,
  )
  @IsString()
  @Matches(/^\d{4}-\d{2}$/, { message: 'registration_month must be YYYY-MM' })
  registration_month?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  display_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  city?: string;

  /** `YYYY-MM` of her most recent order. */
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? foldDigits(value).trim() : value,
  )
  @IsString()
  @Matches(/^\d{4}-\d{2}$/, { message: 'last_order_month must be YYYY-MM' })
  last_order_month?: string;

  /** Roughly what that order came to. Matched within two per cent. */
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? Number(foldDigits(value).trim()) : value,
  )
  @IsNumber()
  @Min(0)
  last_order_total?: number;

  /** What one of her devices is called in her device list. */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  device_label?: string;
}

/** The claimant checking back, holding the secret she was given. */
export class RecoveryCaseStatusDto {
  @IsString()
  @MinLength(16)
  @MaxLength(128)
  claim_secret!: string;
}

export class ReviewRecoveryCaseDto {
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;
}

export class RejectRecoveryCaseDto {
  @IsString()
  @MinLength(3)
  @MaxLength(1000)
  reason!: string;
}

export class RecoveryCaseQueryDto {
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(AccountRecoveryStatus)
  status?: AccountRecoveryStatus;

  @IsOptional()
  @Transform(({ value }) => (value === undefined ? value : Number(value)))
  @IsInt()
  @Min(1)
  @Max(100)
  take?: number;

  @IsOptional()
  @Transform(({ value }) => (value === undefined ? value : Number(value)))
  @IsInt()
  @Min(0)
  skip?: number;
}
