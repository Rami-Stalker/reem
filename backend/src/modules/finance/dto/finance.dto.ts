import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsIn,
  IsISO8601,
  IsInt,
  IsNumberString,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';
import { Currency } from '@prisma/client';

export class CurrencyQueryDto {
  @IsOptional()
  @IsEnum(Currency)
  currency?: Currency;
}

/**
 * Q56 — a courier's cash for one specific day.
 *
 * `date` lives on the DTO rather than in its own `@Query('date')` parameter:
 * the global pipe validates the whole query object with `forbidNonWhitelisted`,
 * so a field this class does not declare is refused outright.
 */
export class CourierExpectedCashQueryDto extends CurrencyQueryDto {
  @IsOptional()
  @IsISO8601()
  date?: string;
}

/**
 * Asking to be paid — Q69 P1.
 *
 * There is no amount field, deliberately. A payout is a set of commission
 * ledgers, each the settled record of one sale; paying half of one would mean
 * splitting a row that the order, its commission and its escrow release all
 * point at. She asks for what is released, or she waits for the rest.
 */
export class RequestPayoutDto {
  @IsOptional()
  @IsEnum(Currency)
  currency?: Currency;
}

// ── Disputes (Q107) ────────────────────────────────────────────────────────

export class OpenDisputeDto {
  @IsUUID()
  seller_order_id!: string;

  @IsString()
  @MaxLength(280)
  subject!: string;

  /**
   * Optional partial freeze. Omitted, the whole sub-order net is held — the
   * conservative default while the facts are unknown.
   */
  @IsOptional()
  @Transform(({ value }) => String(value))
  @IsNumberString()
  amount?: string;
}

export const DISPUTE_OUTCOMES = ['CUSTOMER', 'SELLER', 'SPLIT'] as const;
export type DisputeOutcome = (typeof DISPUTE_OUTCOMES)[number];

export class DecideDisputeDto {
  @IsIn(DISPUTE_OUTCOMES)
  outcome!: DisputeOutcome;

  /** Required when the outcome is SPLIT: the customer's share. */
  @IsOptional()
  @Transform(({ value }) => String(value))
  @IsNumberString()
  customer_share?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;
}

export class AppealDisputeDto {
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;
}

// ── Courier cash settlement (Q56) ──────────────────────────────────────────

export class SettleCourierCashDto {
  @IsUUID()
  courier_id!: string;

  /** The day being settled, as `YYYY-MM-DD`. */
  @IsISO8601()
  date!: string;

  /** What the courier actually handed over — a decimal string, never a float. */
  @Transform(({ value }) => String(value))
  @IsNumberString()
  collected!: string;

  @IsOptional()
  @IsEnum(Currency)
  currency?: Currency;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

// ── Loyalty (Q43) ──────────────────────────────────────────────────────────

export class ConvertPointsDto {
  @Type(() => Number)
  @IsInt()
  @Min(10)
  points!: number;
}

/** Q107 — one side of the argument, with whatever proves it. */
export class DisputeMessageDto {
  @IsString()
  @MaxLength(2000)
  body!: string;

  /** Photo URLs from the media service. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(8)
  @IsString({ each: true })
  evidence?: string[];

  /**
   * A note support leaves for support. Refused for anyone else — the service
   * checks the role rather than trusting the flag.
   */
  @IsOptional()
  @IsBoolean()
  is_internal?: boolean;
}
