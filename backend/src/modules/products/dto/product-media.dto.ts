import { IsEnum, IsInt, IsOptional, Min } from 'class-validator';
import { MediaType } from '@prisma/client';
import { MediaUrlField } from '../../../common/dto/media-url.decorator';

export class ProductMediaDto {
  @MediaUrlField()
  url!: string;

  @IsOptional()
  @IsEnum(MediaType)
  type?: MediaType;

  @IsOptional()
  @IsInt()
  @Min(0)
  sort_order?: number;
}
