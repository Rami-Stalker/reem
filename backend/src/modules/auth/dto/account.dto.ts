import { Transform } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsInt,
  IsEmail,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  Max,
  Min,
} from 'class-validator';
import { foldDigits, PhoneField } from '../../../common/phone/phone';

export class UpdateAccountDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name?: string;

  /**
   * Contact detail only — it is not a login identifier and never was meant to
   * be one. Kept so a seller can publish a business address.
   */
  @IsOptional()
  @IsEmail()
  @MaxLength(160)
  email?: string;

  // `phone` and `phone_otp_code` are gone from this DTO on purpose. One code,
  // on the number being moved *to*, is exactly what a SIM swapper can produce
  // — so changing the number now runs through `/auth/account/phone/*`, which
  // challenges the outgoing number first. See `PhoneChangeService`.

  @IsOptional()
  @IsString()
  @MaxLength(160)
  location?: string;
}

// `ChangePasswordDto` moved to `password-credential.dto.ts` as
// `SetPasswordDto`, along with the single endpoint that now owns passwords.

export class SecuritySettingsDto {
  @IsOptional()
  @IsBoolean()
  mfa_enabled?: boolean;

  @IsOptional()
  @IsBoolean()
  device_verification_required?: boolean;
}

export class RenameDeviceDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name!: string;
}

export class SubmitSellerVerificationDto {
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  business_name!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(160)
  legal_name!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  business_category!: string;

  @IsString()
  @MinLength(20)
  @MaxLength(2000)
  store_description!: string;

  @IsString()
  @MaxLength(500)
  store_logo_url!: string;

  @PhoneField()
  contact_phone!: string;

  @IsEmail()
  @MaxLength(160)
  contact_email!: string;

  @IsString()
  @MinLength(5)
  @MaxLength(500)
  business_address!: string;

  @IsString()
  @MinLength(5)
  @MaxLength(500)
  warehouse_address!: string;

  @IsString()
  @MinLength(4)
  @MaxLength(120)
  commercial_registration!: string;

  @IsString()
  @MaxLength(500)
  government_id_url!: string;

  @IsString()
  @MaxLength(500)
  business_license_url!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  tax_id?: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  bank_name!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(160)
  account_holder!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(34)
  iban!: string;

  @IsOptional()
  @IsObject()
  payment_information?: Record<string, unknown>;

  @IsArray()
  @IsString({ each: true })
  shipping_methods!: string[];

  @IsString()
  @MinLength(10)
  @MaxLength(2000)
  return_policy!: string;

  @IsArray()
  @IsString({ each: true })
  product_categories!: string[];

  @IsInt()
  @Min(0)
  @Max(100)
  years_experience!: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  website?: string;

  @IsOptional()
  @IsObject()
  social_media_links?: Record<string, unknown>;

  @IsArray()
  @IsString({ each: true })
  document_urls!: string[];
}

export class ReviewSellerVerificationDto {
  @IsString()
  @IsIn([
    'UNDER_REVIEW',
    'NEEDS_MORE_DOCUMENTS',
    'APPROVED',
    'REJECTED',
    'NEEDS_MORE_INFO',
    'SUSPENDED',
  ])
  status!:
    | 'UNDER_REVIEW'
    | 'NEEDS_MORE_DOCUMENTS'
    | 'APPROVED'
    | 'REJECTED'
    | 'NEEDS_MORE_INFO'
    | 'SUSPENDED';

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  rejection_reason?: string;
}
