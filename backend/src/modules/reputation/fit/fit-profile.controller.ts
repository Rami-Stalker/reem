import { Body, Controller, Get, Put } from '@nestjs/common';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { SelfScoped } from '../../../common/decorators/self-scoped.decorator';
import { FitProfileService, serializeFitProfile } from './fit-profile.service';
import { HEIGHT_MAX_CM, HEIGHT_MIN_CM, USUAL_SIZES } from './fit-reviews';

/**
 * `null` clears a field; an absent field is left alone. `@ValidateIf` is what
 * lets the null past the number check.
 */
export class FitProfileDto {
  @ValidateIf((_, value) => value !== null && value !== undefined)
  @Type(() => Number)
  @IsInt()
  @Min(HEIGHT_MIN_CM)
  @Max(HEIGHT_MAX_CM)
  height_cm?: number | null;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsString()
  @MaxLength(8)
  usual_size?: string | null;

  @IsOptional()
  @IsBoolean()
  share_on_reviews?: boolean;
}

/**
 * `/fit-profile` — «مقاساتي».
 *
 * Hers alone. There is no route that reads another woman's profile, by id or
 * otherwise; what other women see is the snapshot on a review she chose to
 * share it on.
 */
@SelfScoped("a fit profile is keyed on the caller's own id and has no other reader")
@Controller('fit-profile')
export class FitProfileController {
  constructor(private readonly profiles: FitProfileService) {}

  @Get()
  async get(@CurrentUser('id') userId: string) {
    return {
      ...serializeFitProfile(await this.profiles.get(userId)),
      // The closed list the client builds its size picker from, so the app
      // and the matcher can never offer different sizes.
      sizes: USUAL_SIZES,
    };
  }

  @Put()
  async set(@CurrentUser('id') userId: string, @Body() dto: FitProfileDto) {
    const profile = await this.profiles.set(userId, {
      heightCm: dto.height_cm,
      usualSize: dto.usual_size,
      shareOnReviews: dto.share_on_reviews,
    });
    return { ...serializeFitProfile(profile), sizes: USUAL_SIZES };
  }
}
