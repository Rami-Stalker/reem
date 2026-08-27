import { Transform, Type } from 'class-transformer';
import {
  IsEnum,
  IsISO8601,
  IsLatitude,
  IsLongitude,
  IsNumberString,
  IsOptional,
  IsString,
  IsUUID,
  IsUrl,
  MaxLength,
} from 'class-validator';
import { DeliveryFailureReason } from '@prisma/client';

export class AssignCourierDto {
  @IsUUID()
  courier_id!: string;
}

export class CourierPositionDto {
  @IsOptional()
  @Type(() => Number)
  @IsLatitude()
  latitude?: number;

  @IsOptional()
  @Type(() => Number)
  @IsLongitude()
  longitude?: number;
}

/** Q55 — «يسجّل مبلغ التحصيل» + «يرفع صورة إثبات تسليم». */
export class DeliverShipmentDto extends CourierPositionDto {
  /**
   * A decimal string, never a JSON number: money must not pass through a
   * float. Omitted means the courier collected exactly what was due.
   */
  @IsOptional()
  @Transform(({ value }) => String(value))
  @IsNumberString()
  collected?: string;

  @IsOptional()
  @IsUrl({ require_tld: false })
  proof_image_url?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  recipient_note?: string;
}

/** Q55 — «يسجّل سبب فشل التسليم». */
export class FailDeliveryDto {
  @IsEnum(DeliveryFailureReason)
  reason!: DeliveryFailureReason;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class CourierDayQueryDto {
  @IsOptional()
  @IsISO8601()
  date?: string;
}
