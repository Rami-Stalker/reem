import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  PRODUCT_INCLUDE,
  type ProductRecord,
} from '../../common/catalog/product-include';

// The include lives in common/catalog so the nine modules that load products
// share one definition; re-exported here for the existing import sites.
export {
  PRODUCT_INCLUDE,
  PRODUCT_CARD_INCLUDE,
  type ProductRecord,
} from '../../common/catalog/product-include';

@Injectable()
export class ProductsRepository {
  constructor(private readonly prisma: PrismaService) {}

  findById(id: string): Promise<ProductRecord | null> {
    return this.prisma.product.findUnique({
      where: { id },
      include: PRODUCT_INCLUDE,
    });
  }

  /**
   * Ownership of a canonical product is expressed through its offers: a seller
   * may manage the catalog entry they list on. Admin bypasses this entirely.
   */
  findOwner(id: string) {
    return this.prisma.product.findUnique({
      where: { id },
      select: {
        id: true,
        status: true,
        createdBySellerId: true,
        offers: { select: { id: true, sellerId: true } },
      },
    });
  }

  findOffer(offerId: string) {
    return this.prisma.sellerOffer.findUnique({
      where: { id: offerId },
      include: { seller: true, variants: { include: { variant: true } } },
    });
  }

  create(data: Prisma.ProductCreateInput): Promise<ProductRecord> {
    return this.prisma.product.create({ data, include: PRODUCT_INCLUDE });
  }

  update(id: string, data: Prisma.ProductUpdateInput): Promise<ProductRecord> {
    return this.prisma.product.update({
      where: { id },
      data,
      include: PRODUCT_INCLUDE,
    });
  }

  delete(id: string): Promise<unknown> {
    return this.prisma.product.delete({ where: { id } });
  }

  list(args: {
    where: Prisma.ProductWhereInput;
    orderBy: Prisma.ProductOrderByWithRelationInput[];
    skip: number;
    take: number;
  }): Promise<ProductRecord[]> {
    return this.prisma.product.findMany({
      where: args.where,
      orderBy: args.orderBy,
      skip: args.skip,
      take: args.take,
      include: PRODUCT_INCLUDE,
    });
  }

  count(where: Prisma.ProductWhereInput): Promise<number> {
    return this.prisma.product.count({ where });
  }

  findVariant(productId: string, variantId: string) {
    return this.prisma.productVariant.findFirst({
      where: { id: variantId, productId },
    });
  }

  createVariant(data: Prisma.ProductVariantCreateInput) {
    return this.prisma.productVariant.create({ data });
  }

  updateVariant(id: string, data: Prisma.ProductVariantUpdateInput) {
    return this.prisma.productVariant.update({ where: { id }, data });
  }

  deleteVariant(id: string) {
    return this.prisma.productVariant.delete({ where: { id } });
  }
}
