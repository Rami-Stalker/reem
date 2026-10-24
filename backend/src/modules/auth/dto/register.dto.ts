import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  Equals,
  IsArray,
  IsBoolean,
  IsEnum,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';
import { UserRole } from '@prisma/client';
import { PhoneField } from '../../../common/phone/phone';

export class RegisterDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  first_name?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  last_name?: string;

  @PhoneField()
  phone!: string;

  /**
   * Proof that the number was verified moments ago, issued by
   * `POST /auth/otp/login` when the code came back for a number with no
   * account. Required: nothing creates an account for a number nobody has
   * proved control of.
   */
  @IsString()
  @MinLength(20)
  @MaxLength(2048)
  registration_ticket!: string;

  /**
   * Optional, and the default is not to have one (owner decision 1).
   *
   * A Ohara account signs in with a code on her SIM. A password is an
   * accelerator she may add later, and by design it can never admit a device
   * the account has not already used — so leaving this out costs her nothing
   * and removes the credential most likely to be reused from a breached site.
   */
  @IsOptional()
  @IsString()
  @MinLength(10)
  @MaxLength(128)
  password?: string;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  country!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  city!: string;

  /**
   * Q43/Q138 P1 — the platform is for women, enforced by self-declaration at
   * signup and nothing else. The column existed and defaulted to `true`, which
   * meant the attestation was assumed rather than made: no request ever
   * carried it and no code ever read it. Requiring it here is what turns the
   * rule into something the account actually asserts, and what makes
   * `declaredFemaleAt` a record of when she asserted it.
   */
  @IsBoolean()
  @Equals(true, {
    message: 'declared_female must be accepted to register on Ohara',
  })
  declared_female!: boolean;


  /**
   * The version ids of every policy the form displayed and she accepted.
   *
   * Version ids rather than a bare `accepted_terms: true`, because the record
   * this produces has to be able to answer "agreed to *what*" years later, and
   * a boolean cannot. The server checks that every required document's
   * currently published version is in this list and refuses otherwise.
   */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsUUID(undefined, { each: true })
  accepted_policy_version_ids?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(16)
  preferred_language?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  shipping_address?: string;

  /** Buyers map to CUSTOMER internally. Privileged roles cannot self-register. */
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
