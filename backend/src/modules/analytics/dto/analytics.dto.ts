import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { AnalyticsEventType, AnalyticsExportFormat } from '@prisma/client';

const upper = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.toUpperCase() : value;

export class AnalyticsQueryDto {
  @IsOptional()
  @IsISO8601()
  start_date?: string;

  @IsOptional()
  @IsISO8601()
  end_date?: string;

  @IsOptional()
  @IsUUID()
  seller_id?: string;

  @IsOptional()
  @IsUUID()
  product_id?: string;
}

export class TrackAnalyticsEventDto {
  @Transform(upper)
  @IsEnum(AnalyticsEventType)
  type!: AnalyticsEventType;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  session_id?: string;

  @IsOptional()
  @IsUUID()
  product_id?: string;

  @IsOptional()
  @IsUUID()
  seller_id?: string;

  @IsOptional()
  @IsUUID()
  order_id?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  source?: string;

  @IsOptional()
  metadata?: unknown;
}

export class AnalyticsExportQueryDto extends AnalyticsQueryDto {
  @IsOptional()
  @Transform(upper)
  @IsEnum(AnalyticsExportFormat)
  format: AnalyticsExportFormat = AnalyticsExportFormat.PDF;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  report_type = 'dashboard';
}
