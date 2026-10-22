import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/** Finance matched the transfer. The note is kept on the payment's history. */
export class ConfirmTransferDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}

/** Finance could not match it. The reason is shown to the customer. */
export class RejectTransferDto {
  @IsString()
  @MinLength(3)
  @MaxLength(200)
  reason!: string;
}
