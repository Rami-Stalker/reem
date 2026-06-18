import { IsOptional, IsString, IsUrl, MaxLength, MinLength } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string | null;

  @IsOptional()
  @IsUrl({}, { message: 'image_url must be a valid URL' })
  image_url?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string | null;
}
