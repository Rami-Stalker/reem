import { Transform } from 'class-transformer';
import {
  Allow,
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import {
  CommissionStatus,
  ModerationStatus,
  ProductStatus,
  ReportStatus,
  SupportPriority,
  SupportTicketStatus,
  UserRole,
} from '@prisma/client';

export class AdminListQueryDto {
  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  page = 1;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 25;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  q?: string;

  /**
   * Queue filter, validated per endpoint rather than here.
   *
   * Each list this serves has its own status enum — a moderation case, a
   * support ticket and a seller application do not share one — so the DTO
   * carries the raw token and the service casts it into the filter its own
   * table understands. Prisma rejects a value that is not in the enum, which
   * is the check that matters.
   */
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsString()
  @MaxLength(40)
  status?: string;
}

/** Why a staff member did it. Ends up in the audit entry, not on the record. */
class AdminReasonDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class UpdateUserAdminDto extends AdminReasonDto {
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(UserRole)
  role?: UserRole;

  @IsOptional()
  @IsBoolean()
  disabled?: boolean;
}

export class UpdateProductAdminDto extends AdminReasonDto {
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(ProductStatus)
  status?: ProductStatus;

  /** Homepage curation (Q70). Belongs to the product, not to a seller's offer. */
  @IsOptional()
  @IsBoolean()
  is_featured?: boolean;

  @IsOptional()
  @IsBoolean()
  show_in_feed?: boolean;
}

export class UpdateSupportTicketDto {
  @IsOptional()
  @IsEnum(SupportTicketStatus)
  status?: SupportTicketStatus;

  @IsOptional()
  @IsEnum(SupportPriority)
  priority?: SupportPriority;
}

export class UpdateModerationCaseDto {
  @IsEnum(ModerationStatus)
  status!: ModerationStatus;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  resolution?: string;
}

export class CreateCommissionRuleDto {
  @IsString()
  @MaxLength(120)
  name!: string;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(0)
  @Max(5000)
  rate_bps!: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  category?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  seller_tier?: string;
}

export class UpdateCommissionLedgerDto {
  @IsEnum(CommissionStatus)
  status!: CommissionStatus;
}

export class UpdateReportDto {
  @IsEnum(ReportStatus)
  status!: ReportStatus;
}

export class UpsertSystemSettingDto {
  @IsString()
  @MaxLength(120)
  key!: string;

  /**
   * A setting's value is arbitrary JSON — a flag, a rate, a nested object —
   * so there is nothing to validate its shape against.
   *
   * `@Allow()` is not decoration: the global pipe runs `whitelist` with
   * `forbidNonWhitelisted`, so a property carrying no class-validator
   * decorator at all is not merely stripped, it is *rejected*. Without this
   * the route answered every well-formed request with
   * `400 property value should not exist`, which is why the console could
   * never write a setting.
   */
  @Allow()
  value!: unknown;

  @IsOptional()
  @IsBoolean()
  sensitive?: boolean;
}
