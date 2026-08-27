import { IsString, MaxLength, MinLength } from 'class-validator';

export class TotpCodeDto {
  @IsString()
  @MinLength(6)
  @MaxLength(8)
  code!: string;
}
