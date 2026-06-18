import { IsBoolean, IsOptional } from 'class-validator';

export class UpdatePreferencesDto {
  @IsOptional() @IsBoolean() in_app_posts?: boolean;
  @IsOptional() @IsBoolean() in_app_stories?: boolean;
  @IsOptional() @IsBoolean() in_app_orders?: boolean;
  @IsOptional() @IsBoolean() in_app_coupons?: boolean;
  @IsOptional() @IsBoolean() push?: boolean;
  @IsOptional() @IsBoolean() email?: boolean;
  @IsOptional() @IsBoolean() sms?: boolean;
}
