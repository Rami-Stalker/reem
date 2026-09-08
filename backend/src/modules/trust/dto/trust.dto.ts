import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { TrustBand, TrustSignalStatus, TrustSubject } from '@prisma/client';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export class TrustQueueQueryDto extends PaginationDto {
  @IsOptional()
  @IsEnum(TrustSubject)
  subject?: TrustSubject;

  @IsOptional()
  @IsEnum(TrustBand)
  band?: TrustBand;

  /** Defaults to OPEN in the service — a queue shows what is unworked. */
  @IsOptional()
  @IsEnum(TrustSignalStatus)
  status?: TrustSignalStatus;
}

export class ResolveTrustSignalDto {
  /**
   * `OPEN` is not accepted: this endpoint records a decision, and "I have not
   * decided" is what the row already says.
   */
  @IsEnum(TrustSignalStatus)
  status!: TrustSignalStatus;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;
}

export class TrustSweepDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(365)
  since_days? = 7;

  /**
   * Bounded, and low by default. A sweep that scores the whole table is an
   * outage waiting for the catalogue to grow.
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5000)
  limit? = 500;
}
