import { Transform } from 'class-transformer';
import {
  IsIn,
  IsNumberString,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

import { SELLER_QUEUE_TABS, QueueTab } from '../seller-orders.service';

export class SellerQueueQueryDto {
  /** Which tab of her queue; omitted, everything. */
  @IsOptional()
  @IsIn(SELLER_QUEUE_TABS)
  tab?: QueueTab;
}

export class HandOverDto {
  /** Who took it — a courier company, a driver's name, a waybill number. */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  carrier?: string;
}

export class SellerDeliverDto {
  /**
   * What she collected at the door, as a decimal string — never a JSON number,
   * because money must not pass through a float. Omitted for a prepaid parcel.
   */
  @IsOptional()
  @Transform(({ value }) => String(value))
  @IsNumberString()
  collected?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class SellerCancelOrderDto {
  /**
   * Mandatory. A cancellation is the seller's own quality record and the
   * customer's only explanation; one with neither is worth nothing to either.
   */
  @IsString()
  @MinLength(5)
  @MaxLength(500)
  reason!: string;
}
