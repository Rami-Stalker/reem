import { IsString, Length, Matches } from 'class-validator';

export class ConfirmCodOrderDto {
  /** The six digits from the message sent to the delivery number. */
  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/, { message: 'code must be six digits' })
  code!: string;
}
