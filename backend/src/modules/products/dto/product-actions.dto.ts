import { IsInt, IsOptional, Max, Min } from 'class-validator';

export class OrderCountDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1000)
  amount?: number;
}
