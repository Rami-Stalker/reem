import { Transform } from 'class-transformer';
import { IsString, MaxLength, MinLength } from 'class-validator';
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
  @Transform(({ value }) =>
    typeof value === 'string' ? foldDigits(value).trim() : value,
  )
  @IsString()
  @MinLength(4)
  @MaxLength(8)
  code!: string;
}
