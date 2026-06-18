import { IsEnum, IsOptional, IsString, IsUrl } from 'class-validator';
import { MediaType } from '@prisma/client';

export class CreateStoryDto {
  @IsUrl()
  media_url!: string;

  @IsOptional()
  @IsUrl()
  link?: string | null;

  @IsOptional()
  @IsEnum(MediaType)
  type?: MediaType;
}
