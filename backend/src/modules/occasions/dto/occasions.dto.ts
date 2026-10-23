import {
  IsBoolean,
  IsEnum,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { OccasionKind } from '@prisma/client';

/**
 * The request shapes for «مناسباتي».
 *
 * Snake_case on the wire like the rest of this API. On the patch, `look_id`
 * and `appointment_id` distinguish **absent** (leave it) from **null** (unlink
 * it); `@ValidateIf` is what lets a null through the UUID check, and the
 * controller reads the difference with `!== undefined`.
 */

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;

export class CreateOccasionDto {
  @IsString()
  @MaxLength(80)
  title!: string;

  @IsEnum(OccasionKind)
  kind!: OccasionKind;

  /** `YYYY-MM-DD`, her local calendar day. */
  @Matches(DATE)
  date!: string;

  /** `HH:mm`, local. */
  @IsOptional()
  @Matches(TIME)
  starts_at_time?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string;

  /** Who will be there. What the repeat warning matches on. */
  @IsOptional()
  @IsString()
  @MaxLength(80)
  circle?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsUUID()
  look_id?: string;

  @IsOptional()
  @IsUUID()
  appointment_id?: string;

  @IsOptional()
  @IsBoolean()
  reminders_enabled?: boolean;
}

export class UpdateOccasionDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  title?: string;

  @IsOptional()
  @IsEnum(OccasionKind)
  kind?: OccasionKind;

  @IsOptional()
  @Matches(DATE)
  date?: string;

  /** Null clears it. */
  @ValidateIf((_, value) => value !== null && value !== undefined)
  @Matches(TIME)
  starts_at_time?: string | null;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsString()
  @MaxLength(120)
  location?: string | null;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsString()
  @MaxLength(80)
  circle?: string | null;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsString()
  @MaxLength(500)
  note?: string | null;

  /** Null unlinks the look; absent leaves it. */
  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsUUID()
  look_id?: string | null;

  /** Null unlinks the appointment; absent leaves it. */
  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsUUID()
  appointment_id?: string | null;

  @IsOptional()
  @IsBoolean()
  reminders_enabled?: boolean;
}

export class ListOccasionsDto {
  @IsOptional()
  @IsIn(['upcoming', 'past'])
  scope?: 'upcoming' | 'past';
}

export class SetStepDto {
  @IsBoolean()
  done!: boolean;
}
