import { Transform, Type } from 'class-transformer';
import {
  IsEnum,
  IsISO8601,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { CommissionStatus, Currency, PayoutStatus } from '@prisma/client';

export class CommissionRuleDto {
  @IsString()
  @MaxLength(120)
  name!: string;

  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(0)
  @Max(5000)
  rate_bps!: number;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(0)
  @Max(2000)
  platform_fee_bps?: number;

  /** Fixed fees and bounds are stated in the rule's own currency. */
  @IsOptional()
  @IsEnum(Currency)
  currency?: Currency;

  @IsOptional()
  @Type(() => Number)
  @Min(0)
  fixed_fee?: number;

  @IsOptional()
  @Type(() => Number)
  @Min(0)
  min_commission?: number;

  @IsOptional()
  @Type(() => Number)
  @Min(0)
  max_commission?: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  category?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  seller_tier?: string;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(0)
  @Max(1000)
  priority?: number;
}

export class CommissionLedgerStatusDto {
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(CommissionStatus)
  status!: CommissionStatus;
}

export class PayoutCalculationDto {
  @IsUUID()
  seller_id!: string;

  @IsISO8601()
  period_start!: string;

  @IsISO8601()
  period_end!: string;

  /** A payout settles ONE currency — see CommissionsService.calculatePayout. */
  @IsOptional()
  @IsEnum(Currency)
  currency?: Currency;

  @IsOptional()
  @Type(() => Number)
  adjustments?: number;
}

export class PayoutStatusDto {
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(PayoutStatus)
  status!: PayoutStatus;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  reference?: string;
}

export class CommissionReportQueryDto {
  @IsOptional()
  @IsISO8601()
  start?: string;

  @IsOptional()
  @IsISO8601()
  end?: string;

  @IsOptional()
  @IsUUID()
  seller_id?: string;
}
