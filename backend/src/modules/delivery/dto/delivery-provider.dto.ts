import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { DeliveryProviderKind, ShipmentStatus, WebhookAuthScheme } from '@prisma/client';

import { PaginationDto } from '../../../common/dto/pagination.dto';

/**
 * Registering a delivery company.
 *
 * `code` must match an adapter the build ships; the service checks that before
 * writing, so an account can never point at nothing. Secrets are refused here
 * by shape — the only thing this DTO accepts about a credential is the *name*
 * of the environment variable holding it.
 */
export class CreateDeliveryProviderDto {
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  @Matches(/^[a-z0-9_]+$/, {
    message: 'code must be lower-case letters, digits and underscores',
  })
  code!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  display_name!: string;

  /**
   * Which adapter class speaks to this carrier. Defaults to `code`, which is
   * right for the built-in accounts and wrong for a real company — an account
   * for «أكمي» runs on the `http_generic` adapter, not on an adapter called
   * «أكمي».
   */
  @IsOptional()
  @IsString()
  @MaxLength(60)
  @Matches(/^[a-z0-9_]+$/)
  adapter?: string;

  @IsOptional()
  @IsEnum(DeliveryProviderKind)
  kind?: DeliveryProviderKind;

  @IsOptional()
  @IsBoolean()
  is_enabled?: boolean;

  @IsOptional()
  @IsBoolean()
  is_default?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10_000)
  priority?: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(60, { each: true })
  governorates?: string[];

  @IsOptional()
  @IsBoolean()
  supports_quote?: boolean;

  @IsOptional()
  @IsBoolean()
  supports_cancel?: boolean;

  @IsOptional()
  @IsBoolean()
  supports_tracking?: boolean;

  @IsOptional()
  @IsBoolean()
  supports_webhook?: boolean;

  @IsOptional()
  @IsEnum(WebhookAuthScheme)
  webhook_auth?: WebhookAuthScheme;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  webhook_signature_header?: string;

  /** Non-secret settings. Rejected if it looks like it carries a credential. */
  @IsOptional()
  @IsObject()
  config?: Record<string, unknown>;

  /** `{"apiKey":"ACME_API_KEY"}` — names of environment variables, never values. */
  @IsOptional()
  @IsObject()
  credential_env_keys?: Record<string, string>;

  /** For an INTERNAL account: which in-house courier it dispatches to. */
  @IsOptional()
  @IsString()
  courier_id?: string;
}

export class UpdateDeliveryProviderDto extends CreateDeliveryProviderDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  declare code: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  declare display_name: string;
}

export class DispatchQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  @MaxLength(60)
  provider?: string;

  @IsOptional()
  @IsEnum(ShipmentStatus)
  status?: ShipmentStatus;

  /** Only dispatches the carrier never accepted — the ops retry queue. */
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  failed_only?: boolean;
}

export class CancelDispatchDto {
  @IsOptional()
  @IsString()
  @MaxLength(300)
  reason?: string;
}
