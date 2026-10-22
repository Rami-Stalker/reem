import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import {
  AccountVerificationKind,
  AccountVerificationStatus,
} from '@prisma/client';

/** What she submits, and what she may resubmit after a «نحتاج توضيح». */
export class SubmitAccountVerificationDto {
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(AccountVerificationKind)
  kind?: AccountVerificationKind;

  /// The name on the document — the thing actually being checked.
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  legal_name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  document_type?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  document_front_url?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  document_back_url?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  selfie_url?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(6)
  @IsString({ each: true })
  @MaxLength(2048, { each: true })
  supporting_urls?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;
}

/**
 * A reviewer's decision.
 *
 * `reason` is required for every outcome, approvals included. An approval with
 * no note is a badge nobody can later explain, and this queue is the one place
 * in the product where staff hand out a public claim about a real woman.
 */
export class ReviewAccountVerificationDto {
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(AccountVerificationStatus)
  status!: AccountVerificationStatus;

  @IsString()
  @MinLength(3)
  @MaxLength(1000)
  reason!: string;
}

export class AccountVerificationQueryDto {
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(AccountVerificationStatus)
  status?: AccountVerificationStatus;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  q?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}
