import { Transform } from 'class-transformer';
import {
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
}

export class UpdateUserAdminDto {
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

export class UpdateProductAdminDto {
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(ProductStatus)
  status?: ProductStatus;
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

  value!: unknown;

  @IsOptional()
  @IsBoolean()
  sensitive?: boolean;
}
