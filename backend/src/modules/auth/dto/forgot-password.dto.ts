import { PhoneField } from '../../../common/phone/phone';

export class ForgotPasswordDto {
  @PhoneField()
  phone!: string;
}
