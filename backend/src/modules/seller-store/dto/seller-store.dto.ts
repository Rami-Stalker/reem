import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { StoreTeamRole } from '@prisma/client';

import { PhoneField } from '../../../common/phone/phone';

const trimmed = () =>
  Transform(({ value }) => {
    if (typeof value !== 'string') return value;
    const text = value.trim();
    return text.length === 0 ? null : text;
  });

/** «سياسات المتجر». Null clears a note. */
export class UpdateStorePoliciesDto {
  @IsOptional()
  @IsBoolean()
  accepts_exchanges?: boolean;

  @IsOptional()
  @trimmed()
  @IsString()
  @MaxLength(600, { message: 'النص طويل — خليه أقل من ٦٠٠ حرف' })
  exchange_note?: string | null;

  @IsOptional()
  @trimmed()
  @IsString()
  @MaxLength(600, { message: 'النص طويل — خليه أقل من ٦٠٠ حرف' })
  return_note?: string | null;

  @IsOptional()
  @trimmed()
  @IsString()
  @MaxLength(600, { message: 'النص طويل — خليه أقل من ٦٠٠ حرف' })
  care_note?: string | null;

  @IsOptional()
  @trimmed()
  @IsString()
  @MaxLength(600, { message: 'النص طويل — خليه أقل من ٦٠٠ حرف' })
  custom_order_note?: string | null;
}

/** «إعدادات الشحن». */
export class UpdateShippingSettingsDto {
  @IsOptional()
  @trimmed()
  @IsString()
  @MaxLength(40)
  ships_from_governorate?: string | null;

  @IsOptional()
  @trimmed()
  @IsString()
  @MaxLength(80)
  ships_from_area?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(14, { message: 'مدة التجهيز لازم تكون بين ٠ و١٤ يوم' })
  default_handling_days?: number;

  /** Also move every active listing to the new preparation time. */
  @IsOptional()
  @IsBoolean()
  apply_to_listings?: boolean;

  @IsOptional()
  @IsBoolean()
  offers_pickup?: boolean;

  @IsOptional()
  @trimmed()
  @IsString()
  @MaxLength(200)
  pickup_address?: string | null;

  @IsOptional()
  @trimmed()
  @IsString()
  @MaxLength(120)
  pickup_hours?: string | null;

  @IsOptional()
  @trimmed()
  @IsString()
  @MaxLength(400)
  packaging_note?: string | null;
}

export class InviteTeamMemberDto {
  @PhoneField()
  phone!: string;

  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  @IsEnum(StoreTeamRole, { message: 'اختاري صلاحية العضوة' })
  role!: StoreTeamRole;
}

export class UpdateTeamMemberDto {
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  @IsEnum(StoreTeamRole, { message: 'اختاري صلاحية العضوة' })
  role!: StoreTeamRole;
}

export class ActivityQueryDto {
  /** Entries older than this instant — the last `created_at` she saw. */
  @IsOptional()
  @IsDateString()
  before?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;
}
