import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { PhoneField } from '../../../common/phone/phone';

/**
 * Identity is phone-only (Q43 P1). The `identifier` and `email` fields this
 * DTO used to accept are gone: they gave the platform a second login namespace
 * that the requirements do not have, and the `'@'` branch that routed to
 * `findByEmail` meant an account could be reached by a column the product
 * treats as optional contact data.
 */
export class LoginDto {
  @PhoneField()
  phone!: string;

  @IsString()
  @IsNotEmpty()
  password!: string;

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
