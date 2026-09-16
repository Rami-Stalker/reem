import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayNotEmpty,
  IsArray,
  IsEnum,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { UserRole } from '@prisma/client';

/** `?locale=ar` on every read. Unknown values fall back to Arabic. */
export class PolicyLocaleQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(8)
  locale?: string;
}

/**
 * `GET /policies/required?role=seller` — what an account of this kind has to
 * sign before it exists.
 *
 * Accepts `buyer` as a synonym for `customer` the same way registration does,
 * because the app's own vocabulary is «مشترية / بائعة» and the two halves must
 * not disagree about what a role is called.
 */
export class PolicyRequiredQueryDto extends PolicyLocaleQueryDto {
  @IsOptional()
  @Transform(({ value }) => {
    if (typeof value !== 'string') return value;
    const normalized = value.trim().toLowerCase();
    if (normalized === 'buyer' || normalized === 'customer') {
      return UserRole.CUSTOMER;
    }
    if (normalized === 'seller') return UserRole.SELLER;
    return value.toUpperCase();
  })
  @IsEnum(UserRole)
  @IsIn([UserRole.CUSTOMER, UserRole.SELLER], {
    message: 'role must be buyer or seller',
  })
  role?: UserRole;
}

/**
 * `POST /policies/accept` — the consent gate's answer.
 *
 * The client sends the version ids it actually displayed, not document ids.
 * That is the whole evidentiary point: a signature is against a text, and a
 * document id names a moving target.
 */
export class AcceptPoliciesDto {
  @IsArray()
  @ArrayNotEmpty()
  @ArrayMaxSize(20)
  @IsUUID(undefined, { each: true })
  version_ids!: string[];

  /** Which language she read them in. Recorded on every acceptance row. */
  @IsOptional()
  @IsString()
  @MaxLength(8)
  locale?: string;
}
