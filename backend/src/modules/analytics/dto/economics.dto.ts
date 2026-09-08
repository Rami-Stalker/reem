import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsISO8601,
  IsOptional,
  Max,
  Min,
} from 'class-validator';
import { Currency } from '@prisma/client';

/**
 * The window a set of economics is read over.
 *
 * Both ends default rather than being required, because the commonest
 * question is "how are we doing this month" and making a console send two
 * timestamps to ask it is how a screen ends up with a hardcoded range in the
 * client instead.
 */
export class EconomicsQueryDto {
  @IsOptional()
  @IsISO8601()
  from?: string;

  @IsOptional()
  @IsISO8601()
  to?: string;

  /**
   * Figures never cross currencies. An order priced in USD and one in SYP are
   * not addable at any single rate that would still be true a month later —
   * the platform freezes a rate per order for exactly that reason — so the
   * report is run once per currency rather than summed into a fiction.
   */
  @IsOptional()
  @IsEnum(Currency)
  currency?: Currency;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit? = 20;
}
