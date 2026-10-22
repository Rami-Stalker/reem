import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import {
  Currency,
  SalonServiceCategory,
  SalonServiceLocation,
  SalonStatus,
} from '@prisma/client';
import { PaginationDto } from '../../../common/dto/pagination.dto';

/** `HH:mm`, and nothing else. Validated here so the hours parser never has to
 * guess what a salon meant by "9". */
const TIME_OF_DAY = /^([01]\d|2[0-3]):([0-5]\d)$/;

/** `YYYY-MM-DD` in the salon's own local reckoning. */
const LOCAL_DATE = /^\d{4}-\d{2}-\d{2}$/;

const upper = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.toUpperCase() : value;

// ── Browsing ────────────────────────────────────────────────────────────────

/**
 * «البحث والتصفية حسب المنطقة، نوع الخدمة، السعر والتقييم».
 *
 * Every filter is optional and every one of them narrows rather than replaces,
 * so an empty query is the whole live directory — which is what a woman who
 * has just tapped «الصالونات والجمال» should see.
 */
export class SalonQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  q?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  governorate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string;

  @IsOptional()
  @Transform(upper)
  @IsEnum(SalonServiceCategory)
  category?: SalonServiceCategory;

  /** Both bounds are in SYP, against the normalised `price_syp` column. */
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  min_price?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  max_price?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(5)
  min_rating?: number;

  /** Only salons that will come to her. */
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  home_service?: boolean;

  @IsOptional()
  @IsString()
  @Matches(/^(rating|reviews|newest|price_asc|price_desc)$/)
  sort?: string;
}

export class AvailabilityQueryDto {
  @IsUUID()
  service_id!: string;

  @Matches(LOCAL_DATE, { message: 'date must be YYYY-MM-DD' })
  date!: string;
}

export class OpenDaysQueryDto {
  @IsUUID()
  service_id!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(14)
  days = 7;
}

// ── Booking ─────────────────────────────────────────────────────────────────

export class CreateAppointmentDto {
  @IsUUID()
  service_id!: string;

  /**
   * The exact instant, as the availability call returned it.
   *
   * An ISO instant rather than a date plus a time-of-day, deliberately: the
   * client should book the slot it was *offered* rather than re-derive one,
   * and an instant cannot be misread by a phone whose clock is in another
   * timezone.
   */
  @IsString()
  starts_at!: string;

  /** «الخدمات المنزلية». Refused when the service is IN_SALON only. */
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  at_home?: boolean;

  /** Required when `at_home` is true, and must be one of her own addresses. */
  @IsOptional()
  @IsUUID()
  address_id?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class CancelAppointmentDto {
  @IsOptional()
  @IsString()
  @MaxLength(300)
  reason?: string;
}

export class AppointmentQueryDto extends PaginationDto {
  /**
   * `upcoming` | `past` | a literal status.
   *
   * Two words rather than four statuses because that is how she thinks about
   * her own bookings, and the salon's queue asks the same question with the
   * same parameter.
   */
  @IsOptional()
  @IsString()
  @Matches(/^(upcoming|past|PENDING|CONFIRMED|COMPLETED|CANCELLED|NO_SHOW)$/)
  filter?: string;

  /** The salon's day view. */
  @IsOptional()
  @Matches(LOCAL_DATE, { message: 'date must be YYYY-MM-DD' })
  date?: string;
}

export class ReviewAppointmentDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  body?: string;
}

export class ReplyToReviewDto {
  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  body!: string;
}

// ── Owning a salon ──────────────────────────────────────────────────────────

export class UpsertSalonDto {
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  tagline?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  about?: string;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  governorate!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  city!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  district?: string;

  @IsString()
  @MinLength(3)
  @MaxLength(300)
  address_line!: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  landmark?: string;

  @IsOptional()
  @Type(() => Number)
  @IsLatitude()
  latitude?: number;

  @IsOptional()
  @Type(() => Number)
  @IsLongitude()
  longitude?: number;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  whatsapp?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  logo_url?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  cover_url?: string;

  /**
   * The calendar's shape. Bounded rather than free: a five-minute grid on a
   * twelve-hour day is 144 slots a request, and a horizon of a year is a
   * calendar nobody can keep.
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(5)
  @Max(240)
  slot_minutes?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(10080)
  lead_minutes?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(120)
  horizon_days?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  concurrent_capacity?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(168)
  cancellation_hours?: number;

  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  home_service?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  home_service_fee?: number;

  @IsOptional()
  @Transform(upper)
  @IsEnum(Currency)
  currency?: Currency;

  /**
   * DRAFT or ACTIVE, and nothing else.
   *
   * SUSPENDED is an operator's word. A salon must not be able to declare
   * itself suspended, because a suspension is a fact about the platform's
   * judgement and not about the salon's mood.
   */
  @IsOptional()
  @Transform(upper)
  @IsEnum(SalonStatus)
  status?: SalonStatus;
}

export class UpsertSalonServiceDto {
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @Transform(upper)
  @IsEnum(SalonServiceCategory)
  category!: SalonServiceCategory;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  price!: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  compare_at_price?: number;

  @IsOptional()
  @Transform(upper)
  @IsEnum(Currency)
  currency?: Currency;

  @Type(() => Number)
  @IsInt()
  @Min(5)
  @Max(600)
  duration_minutes!: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(240)
  buffer_minutes?: number;

  @IsOptional()
  @Transform(upper)
  @IsEnum(SalonServiceLocation)
  location?: SalonServiceLocation;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  image_url?: string;

  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  is_package?: boolean;

  /** The member services, when this is a package. */
  @IsOptional()
  @IsUUID('4', { each: true })
  package_service_ids?: string[];

  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  is_active?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  sort_order?: number;
}

export class WorkingHoursDayDto {
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(6)
  weekday!: number;

  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  is_closed?: boolean;

  @Matches(TIME_OF_DAY, { message: 'opens_at must be HH:mm' })
  opens_at!: string;

  @Matches(TIME_OF_DAY, { message: 'closes_at must be HH:mm' })
  closes_at!: string;

  @IsOptional()
  @Matches(TIME_OF_DAY, { message: 'break_starts_at must be HH:mm' })
  break_starts_at?: string;

  @IsOptional()
  @Matches(TIME_OF_DAY, { message: 'break_ends_at must be HH:mm' })
  break_ends_at?: string;
}

/** The whole week, replaced at once — a partial update of a timetable is how
 * a salon ends up open on a day it meant to close. */
export class SetWorkingHoursDto {
  @ValidateNested({ each: true })
  @Type(() => WorkingHoursDayDto)
  days!: WorkingHoursDayDto[];
}

export class CreateClosureDto {
  @Matches(LOCAL_DATE, { message: 'date must be YYYY-MM-DD' })
  date!: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  reason?: string;
}

export class SalonNoteDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
