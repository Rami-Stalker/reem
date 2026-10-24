import { Injectable } from '@nestjs/common';
import { ReturnReason, ReturnStatus, SellerOrderStatus } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { SizeFit, SizeSales, sizeAttribute, sizeFit } from './kernel/size-fit';

/**
 * Seller-order statuses at which the pieces had reached her. Everything a
 * return can only start from is here; a cancelled or failed delivery never
 * put the size on anyone, so it says nothing about fit.
 */
const REACHED_CUSTOMER: SellerOrderStatus[] = [
  SellerOrderStatus.DELIVERED,
  SellerOrderStatus.RETURN_REQUESTED,
  SellerOrderStatus.RETURN_IN_TRANSIT,
  SellerOrderStatus.RETURNED,
  SellerOrderStatus.EXCHANGE_IN_PROGRESS,
  SellerOrderStatus.EXCHANGED,
  SellerOrderStatus.REFUND_PENDING,
  SellerOrderStatus.REFUNDED,
  SellerOrderStatus.DISPUTED,
];

/**
 * A request the seller turned down, or that she withdrew, is not evidence
 * the size was wrong.
 */
const VOIDED_RETURNS: ReturnStatus[] = [
  ReturnStatus.REJECTED,
  ReturnStatus.CANCELLED,
];

/**
 * Reads the counts behind a product's size fit. The judgement — what counts
 * as kept, what is too few to say — is the kernel's, in `kernel/size-fit.ts`.
 */
@Injectable()
export class SizeFitService {
  constructor(private readonly prisma: PrismaService) {}

  async forProduct(productId: string): Promise<SizeFit[]> {
    const items = await this.prisma.orderItem.findMany({
      where: {
        productId,
        variantId: { not: null },
        sellerOrder: { status: { in: REACHED_CUSTOMER } },
      },
      select: {
        variantId: true,
        quantity: true,
        returnItems: {
          where: {
            request: {
              reason: ReturnReason.SIZE_ISSUE,
              status: { notIn: VOIDED_RETURNS },
            },
          },
          select: { quantity: true },
        },
      },
    });
    if (items.length === 0) return [];

    const variantIds = [...new Set(items.map((item) => item.variantId!))];
    const variants = await this.prisma.productVariant.findMany({
      where: { id: { in: variantIds } },
      select: { id: true, attributes: true },
    });
    const sizeOf = new Map(
      variants.map((variant) => [variant.id, sizeAttribute(variant.attributes)]),
    );

    const sales: SizeSales[] = [];
    for (const item of items) {
      const size = sizeOf.get(item.variantId!);
      if (!size) continue;
      sales.push({
        size,
        delivered: item.quantity,
        returnedForSize: item.returnItems.reduce(
          (sum, returned) => sum + returned.quantity,
          0,
        ),
      });
    }
    return sizeFit(sales);
  }
}
