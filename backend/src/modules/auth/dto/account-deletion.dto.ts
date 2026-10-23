import { Equals, IsOptional, IsString, MaxLength } from 'class-validator';

/**
 * Deleting the account.
 *
 * `confirm` must be literally `true`: a body that merely reaches this route —
 * a retried request, a client bug posting the wrong payload — must never be
 * enough to wipe an account. The step-up and the device proof decide *who*
 * may do it; this decides that she meant to.
 */
export class DeleteAccountDto {
  @Equals(true)
  confirm!: boolean;

  /** Why she is leaving, if she wants to say. Never required. */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
