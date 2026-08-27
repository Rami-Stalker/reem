import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { StepUpMethod } from '@prisma/client';
import { foldDigits } from '../../../common/phone/phone';

/**
 * The action classes a step-up can be requested for.
 *
 * A closed list rather than free text: a grant is scoped, and an attacker who
 * could name the scope could request one for a harmless action and spend it on
 * a payout change.
 */
export const STEP_UP_SCOPES = [
  'payout_details',
  'password_change',
  'phone_change',
  'device_revocation',
  'logout_others',
  'seller_verification',
  'high_value_checkout',
  'otp_transport_routes',
  'recovery_codes',
  'address_write',
  // Staff scopes. An admin session is worth more than a shopper's, so the two
  // actions where staff reach into somebody else's account are elevated too.
  'account_recovery_review',
  'admin_session_revocation',
  // Opting into — or out of — a password.
  'password_credential',
] as const;

export class RequestStepUpDto {
  @IsIn(STEP_UP_SCOPES)
  scope!: string;
}

export class VerifyStepUpDto {
  @IsIn(STEP_UP_SCOPES)
  scope!: string;

  /// Which factor is being presented. Defaults to the SMS/WhatsApp code so
  /// existing clients keep working.
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(StepUpMethod)
  method?: StepUpMethod;

  @Transform(({ value }) =>
    typeof value === 'string' ? foldDigits(value).trim() : value,
  )
  @IsString()
  @MinLength(4)
  // A recovery code is longer than an OTP.
  @MaxLength(16)
  code!: string;
}
