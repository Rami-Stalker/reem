import { DeliveryFailureReason } from '@prisma/client';
import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsNumberString,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

/** A report from a carrier's driver, or a seller relaying one. */
export class CarrierStepDto {
  /** The four digits the customer reads out at the door. */
  @IsOptional()
  @IsString()
  @Matches(/^\s*\d{4}\s*$/, { message: 'رمز الاستلام أربعة أرقام' })
  handover_code?: string;

  /** Decimal string. Omitted means exactly what was due. */
  @IsOptional()
  @Transform(({ value }) => (value === '' || value == null ? undefined : String(value)))
  @IsNumberString()
  collected?: string;

  @IsOptional()
  @IsEnum(DeliveryFailureReason)
  reason?: DeliveryFailureReason;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
