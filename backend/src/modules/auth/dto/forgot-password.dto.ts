import { IsString, Matches } from 'class-validator';
import { PHONE_REGEX } from '../../../common/constants';

export class ForgotPasswordDto {
  @IsString()
  @Matches(PHONE_REGEX, {
    message: 'phone must be a valid phone number (7–15 digits, optional +)',
  })
  phone!: string;
}
