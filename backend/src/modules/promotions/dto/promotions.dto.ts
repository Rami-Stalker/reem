import { Type } from 'class-transformer';
import {
  IsEnum,
  IsISO8601,
  IsNumber,
  IsUUID,
  Min,
} from 'class-validator';
import { PromotionPlacement, PromotionStatus } from '@prisma/client';

export class CreatePromotionDto {
  @IsUUID()
  offer_id!: string;

  @IsEnum(PromotionPlacement)
  placement!: PromotionPlacement;

  /** Charged once, from her earnings, on the day the placement starts. */
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  fee!: number;

  @IsISO8601()
  starts_at!: string;

  @IsISO8601()
  ends_at!: string;
}

export class SetPromotionStatusDto {
  @IsEnum(PromotionStatus)
  status!: PromotionStatus;
}
