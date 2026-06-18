import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

export const PRODUCT_INCLUDE = {
  seller: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
  variants: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.ProductInclude;

export type ProductRecord = Prisma.ProductGetPayload<{
  include: typeof PRODUCT_INCLUDE;
}>;

@Injectable()
export class ProductsRepository {
  constructor(private readonly prisma: PrismaService) {}

  findById(id: string): Promise<ProductRecord | null> {
    return this.prisma.product.findUnique({
      where: { id },
      include: PRODUCT_INCLUDE,
    });
  }

  findOwner(id: string) {
    return this.prisma.product.findUnique({
      where: { id },
      select: { id: true, sellerId: true, price: true, stock: true, status: true },
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
