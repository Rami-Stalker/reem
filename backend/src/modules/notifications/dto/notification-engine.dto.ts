import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayNotEmpty,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsEnum,
  IsIn,
  IsInt,
  IsISO8601,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import {
  NotificationCampaignStatus,
  NotificationChannel,
  NotificationType,
  NotificationCategory,
  UserRole,
} from '@prisma/client';

export class RegisterPushTokenDto {
  @IsString()
  @MaxLength(4096)
  token!: string;

  @IsString()
  @IsIn(['fcm', 'apns', 'webhook'])
  provider!: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  platform?: string;

  /**
   * The handset, as the handset knows itself.
   *
   * Optional, because a client that predates this field still has to be able
   * to register — but without it the server cannot tell a reinstall from a
   * second phone, and she ends up with both rows and two of every
   * notification. The client generates it once and keeps it in secure
   * storage.
   */
  @IsOptional()
  @IsString()
  @MaxLength(128)
  device_id?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  app_version?: string;

  /** `ar` or `en` — for the day a notification is composed rather than sent. */
  @IsOptional()
  @IsString()
  @MaxLength(16)
  locale?: string;
}

export class UnregisterPushTokenDto {
  @IsString()
  @MaxLength(4096)
  token!: string;
}

/**
 * Who a broadcast reaches. Every field is checked, because each one becomes a
 * clause in a query over the whole user table: an unvalidated role string or
 * a negative day count used to reach Prisma as-is.
 */
export class NotificationSegmentDto {
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @Transform(({ value }) =>
    Array.isArray(value)
      ? value.map((entry) =>
          typeof entry === 'string' ? entry.toUpperCase() : entry,
        )
      : value,
  )
  @IsEnum(UserRole, { each: true })
  roles?: UserRole[];

  @IsOptional()
  @IsBoolean()
  verified_sellers?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  min_points?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(3650)
  inactive_days?: number;
}

/** The most accounts one dispatch may name. A larger audience is a segment. */
export const MAX_DIRECT_RECIPIENTS = 10_000;

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
  @ArrayMaxSize(MAX_DIRECT_RECIPIENTS)
  @ArrayUnique()
  @IsUUID('all', { each: true })
  user_ids?: string[];

  @IsOptional()
  @ValidateNested()
  @Type(() => NotificationSegmentDto)
  segment?: NotificationSegmentDto;

  @IsArray()
  @ArrayNotEmpty()
  @ArrayUnique()
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
  @IsObject()
  payload?: Record<string, unknown>;
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
  @IsISO8601({ strict: true })
  scheduled_at?: string;

  /**
   * Only the app's own scheme. A campaign link is opened by the router on
   * every recipient's phone, so an `https://` link here would be a phishing
   * page delivered by Reem to its whole audience.
   */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  @Matches(/^reem:\/\/[A-Za-z0-9\-._~\/?#&=%]*$/, {
    message: 'deep_link must be an in-app reem:// link',
  })
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
  // A free string here went straight into the event table and onto the
  // analytics screen, so any account could invent event names there.
  @IsIn(['opened', 'clicked', 'delivered', 'failed'])
  event!: 'opened' | 'clicked' | 'delivered' | 'failed';

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}
