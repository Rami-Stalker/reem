import { Transform } from 'class-transformer';
import {
  IsArray,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import {
  NotificationCampaignStatus,
  NotificationChannel,
  NotificationType,
  NotificationCategory,
} from '@prisma/client';

export class RegisterPushTokenDto {
  @IsString()
  token!: string;

  @IsString()
  @MaxLength(40)
  provider!: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  platform?: string;
}

export class NotificationSegmentDto {
  @IsOptional()
  @IsArray()
  roles?: string[];

  @IsOptional()
  verified_sellers?: boolean;

  @IsOptional()
  min_points?: number;

  @IsOptional()
  inactive_days?: number;
}

export class DispatchNotificationDto {
  /**
   * Whether this is something the recipient is waiting for or something the
   * platform wants. Omitted means marketing — the safe default, because a
   * caller that has not thought about it is far likelier to be promoting than
   * to be delivering an order update.
   */
  @IsOptional()
  @IsEnum(NotificationCategory)
  category?: NotificationCategory;

  @IsOptional()
  @IsArray()
  user_ids?: string[];

  @IsOptional()
  segment?: NotificationSegmentDto;

  @IsArray()
  @Transform(({ value }) =>
    Array.isArray(value)
      ? value.map((entry) =>
          typeof entry === 'string' ? entry.toUpperCase() : entry,
        )
      : value,
  )
  @IsEnum(NotificationChannel, { each: true })
  channels!: NotificationChannel[];

  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toLowerCase() : value,
  )
  @IsEnum(NotificationType)
  type?: NotificationType;

  @IsString()
  @MaxLength(160)
  title!: string;

  @IsString()
  @MaxLength(1200)
  body!: string;

  @IsOptional()
  payload?: unknown;
}

export class CreateCampaignDto extends DispatchNotificationDto {
  @IsString()
  @MaxLength(160)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @IsOptional()
  @IsString()
  scheduled_at?: string;

  @IsOptional()
  @IsString()
  deep_link?: string;
}

export class UpdateCampaignStatusDto {
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(NotificationCampaignStatus)
  status!: NotificationCampaignStatus;
}

export class TrackNotificationEventDto {
  @IsString()
  @MaxLength(40)
  event!: 'opened' | 'clicked' | 'delivered' | 'failed';

  @IsOptional()
  metadata?: unknown;
}
