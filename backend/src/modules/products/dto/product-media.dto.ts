import { IsEnum, IsInt, IsOptional, IsUrl, Min } from 'class-validator';
import { MediaType } from '@prisma/client';

export class ProductMediaDto {
  @IsUrl()
  url!: string;

  @IsOptional()
  @IsEnum(MediaType)
  type?: MediaType;

  @IsOptional()
  @IsInt()
  @Min(0)
  sort_order?: number;
}
