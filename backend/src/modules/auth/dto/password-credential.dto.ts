import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/**
 * Opting into a password.
 *
 * Off by default (owner decision 1). It is an accelerator on a device the
 * platform already trusts and nothing more — it cannot admit a new one, which
 * is why enabling it does not weaken the account the way a password normally
 * would.
 */
export class SetPasswordDto {
  /** Required only when replacing an existing password. */
  @IsOptional()
  @IsString()
  @MaxLength(128)
  current_password?: string;

  @IsString()
  @MinLength(10)
  @MaxLength(128)
  new_password!: string;
}
