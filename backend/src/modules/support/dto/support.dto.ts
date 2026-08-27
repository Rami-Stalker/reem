import { IsBoolean, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class OpenTicketDto {
  @IsString()
  @MinLength(3)
  @MaxLength(140)
  subject!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(2000)
  body!: string;

  /** «طلب», «دفع', «حساب» — free text, so a new topic needs no release. */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  category?: string;
}

export class ReplyTicketDto {
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  body!: string;

  /**
   * A note support leaves for support. Refused for anyone else — the service
   * checks the role rather than trusting the flag.
   */
  @IsOptional()
  @IsBoolean()
  internal?: boolean;
}
