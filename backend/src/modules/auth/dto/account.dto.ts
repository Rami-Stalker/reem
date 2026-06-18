import {
  IsArray,
  IsBoolean,
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { PHONE_REGEX } from '../../../common/constants';

export class UpdateAccountDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(160)
  email?: string;

  @IsOptional()
  @IsString()
  @Matches(PHONE_REGEX, {
    message: 'phone must be a valid phone number (7-15 digits, optional +)',
  })
  phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  location?: string;
}

export class ChangePasswordDto {
  @IsString()
  @IsOptional()
  current_password?: string;

  @IsString()
  @MinLength(8)
  @MaxLength(128)
  new_password!: string;
}

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

  @IsOptional()
  @IsString()
  @MaxLength(80)
  tax_id?: string;

  @IsArray()
  @IsString({ each: true })
  document_urls!: string[];
}

export class ReviewSellerVerificationDto {
  @IsString()
  @IsIn(['APPROVED', 'REJECTED', 'NEEDS_MORE_INFO'])
  status!: 'APPROVED' | 'REJECTED' | 'NEEDS_MORE_INFO';

  @IsOptional()
  @IsString()
  @MaxLength(500)
  rejection_reason?: string;
}
