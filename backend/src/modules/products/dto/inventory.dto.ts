import { IsEnum, IsInt } from 'class-validator';
import { ProductStatus } from '@prisma/client';

export class SetProductStatusDto {
  @IsEnum(ProductStatus)
  status!: ProductStatus;
}

export class AdjustStockDto {
  /** Positive to restock, negative to deduct. */
  @IsInt()
  delta!: number;
}
