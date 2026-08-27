import { IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';

/**
 * The cart references a seller's OFFER, not a product: the same product may be
 * listed by several sellers at different prices, so "add to cart" has to say
 * whose listing (Q23/Q27 P2).
 */
export class AddCartItemDto {
  @IsUUID()
  offer_id!: string;

  /** The seller's priced variant row, not the canonical product variant. */
  @IsOptional()
  @IsUUID()
  offer_variant_id?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(99)
  quantity?: number;
}

export class UpdateCartItemDto {
  @IsInt()
  @Min(1)
  @Max(99)
  quantity!: number;
}
