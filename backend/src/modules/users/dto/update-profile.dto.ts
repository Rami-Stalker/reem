import {
  IsEmail,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { MediaUrlField } from '../../../common/dto/media-url.decorator';

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
  @MediaUrlField('image_url must be a valid URL')
  image_url?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string | null;

  /**
   * Q34 — «بريد إلكتروني للاستعادة».
   *
   * The profile checklist has asked for this since it was written, and there
   * was no way to give it: the screen had no field and this DTO had no
   * property, so that step could never be ticked and the completion ring
   * could never reach 100%. An empty string clears it.
   */
  @IsOptional()
  @ValidateIf((_, value) => value !== null && value !== '')
  @IsEmail({}, { message: 'email must be a valid email address' })
  @MaxLength(160)
  email?: string | null;
}
