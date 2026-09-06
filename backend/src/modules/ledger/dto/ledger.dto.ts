import { Transform, Type } from 'class-transformer';
import {
  IsEnum,
  IsIn,
  IsInt,
  IsNumberString,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Currency, WalletTransactionSource } from '@prisma/client';

/**
 * The only wallet credits an admin may originate directly. Refunds and price
 * adjustments are excluded: those carry a funding decision (who absorbs the
 * amount) that belongs to the returns flow, not to a free-text admin form.
 */
export const ADMIN_CREDIT_SOURCES = [
  WalletTransactionSource.ADMIN_COMPENSATION,
  WalletTransactionSource.CAMPAIGN_GIFT,
  WalletTransactionSource.POINTS_CONVERSION,
] as const;

export type AdminCreditSource = (typeof ADMIN_CREDIT_SOURCES)[number];

export class WalletQueryDto {
  @IsOptional()
  @IsEnum(Currency)
  currency?: Currency;

  /**
   * Paging for the statement. Declared here rather than as separate
   * `@Query('skip')` parameters: the global pipe validates the whole query
   * object with `forbidNonWhitelisted`, so anything absent from this DTO is
   * refused before a per-parameter pipe ever sees it.
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  skip?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  take?: number;
}

/**
 * Q41 — «شحن يدوي من الإدارة (تعويض)».
 *
 * The amount arrives as a decimal *string*, not a number: JSON numbers are
 * IEEE-754 doubles, and `1450000.15` does not survive that round trip intact.
 * Money never passes through a float anywhere in this backend.
 */
export class AdminWalletCreditDto {
  @Transform(({ value }) => String(value))
  @IsNumberString({ no_symbols: false })
  amount!: string;

  @IsOptional()
  @IsEnum(Currency)
  currency?: Currency;

  /**
   * Restricted to the sources an admin may originate by hand. A refund is not
   * on this list on purpose — refunds come from the returns flow, which knows
   * who bears the cost, rather than from someone typing an amount.
   */
  @IsIn(ADMIN_CREDIT_SOURCES)
  source!: AdminCreditSource;

  @IsString()
  @MaxLength(280)
  reason!: string;

  /** Idempotency key, so a double-submitted credit lands once. */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  reference?: string;
}
