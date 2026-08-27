import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsISO8601,
  IsInt,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';
import { RiskLevel, SecurityEventType } from '@prisma/client';

export class SecurityEventQueryDto {
  @IsOptional()
  @IsUUID()
  user_id?: string;

  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(SecurityEventType)
  type?: SecurityEventType;

  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(RiskLevel)
  risk_level?: RiskLevel;

  @IsOptional()
  @IsISO8601()
  since?: string;

  @IsOptional()
  @IsISO8601()
  until?: string;

  @IsOptional()
  @Transform(({ value }) => (value === undefined ? value : Number(value)))
  @IsInt()
  @Min(1)
  @Max(200)
  take?: number;

  @IsOptional()
  @Transform(({ value }) => (value === undefined ? value : Number(value)))
  @IsInt()
  @Min(0)
  skip?: number;
}

export class UserTimelineQueryDto {
  @IsOptional()
  @IsISO8601()
  since?: string;

  @IsOptional()
  @Transform(({ value }) => (value === undefined ? value : Number(value)))
  @IsInt()
  @Min(1)
  @Max(500)
  take?: number;
}
