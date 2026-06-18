import { IsNumber, IsOptional, IsString, Min, MinLength } from 'class-validator';

export class DeliveryQuoteDto {
  @IsString()
  @MinLength(2)
  governorate!: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  subtotal?: number;
}
