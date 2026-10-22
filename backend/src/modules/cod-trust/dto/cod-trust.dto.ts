import { IsOptional, IsString, Length, Matches } from 'class-validator';

export class ConfirmCodOrderDto {
  /**
   * The six digits from the message sent to the delivery number.
   *
   * Absent on the reverse rail: there the recipient sent a message from the
   * delivery handset and the confirmation is settled by the provider's answer,
   * so there are no digits for anyone to read out or type in.
   */
  @IsOptional()
  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/, { message: 'code must be six digits' })
  code?: string;
}
