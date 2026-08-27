import { IsEnum, IsOptional, IsString, IsUrl } from 'class-validator';
import { MediaType } from '@prisma/client';
import { MediaUrlField } from '../../../common/dto/media-url.decorator';

export class CreateStoryDto {
  @MediaUrlField()
  media_url!: string;

  @IsOptional()
  @IsUrl()
  link?: string | null;

  @IsOptional()
  @IsEnum(MediaType)
  type?: MediaType;
}
