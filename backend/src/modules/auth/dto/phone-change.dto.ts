import { Transform } from 'class-transformer';
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { foldDigits, PhoneField } from '../../../common/phone/phone';

/** Step one: name the number she is moving to. */
export class StartPhoneChangeDto {
  @PhoneField()
  new_phone!: string;
}

/**
 * Steps two and three, which take the same shape: a code, against the change
 * it belongs to.
 *
 * The request id is required rather than inferred from "her latest pending
 * change" — inferring it is how a second, concurrent change gets its code
 * spent on the first one.
 */
export class PhoneChangeCodeDto {
  /**
   * Optional, because on the reverse rail there is no code: she proved the
   * number by sending a message and the step is settled by the provider's
   * answer. Still validated when present, and a missing code with no reverse
   * ceremony outstanding is refused as an invalid one.
   */
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? foldDigits(value).trim() : value,
  )
  @IsString()
  @MinLength(4)
  @MaxLength(8)
  code?: string;
}
