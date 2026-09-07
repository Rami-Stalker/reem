import { IsBoolean, IsOptional } from 'class-validator';

export class UpdatePreferencesDto {
  @IsOptional() @IsBoolean() in_app_posts?: boolean;
  @IsOptional() @IsBoolean() in_app_stories?: boolean;
  @IsOptional() @IsBoolean() in_app_orders?: boolean;
  @IsOptional() @IsBoolean() in_app_coupons?: boolean;
  // `in_app_rooms` was a column and a settings toggle with no field here and
  // no key in the response, so it could be neither read nor written. Rooms
  // shipped that way; the two social keys join it rather than repeating it.
  @IsOptional() @IsBoolean() in_app_rooms?: boolean;
  @IsOptional() @IsBoolean() in_app_social?: boolean;
  @IsOptional() @IsBoolean() in_app_moderation?: boolean;
  @IsOptional() @IsBoolean() push?: boolean;
  @IsOptional() @IsBoolean() email?: boolean;
  @IsOptional() @IsBoolean() sms?: boolean;
}
