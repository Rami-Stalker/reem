import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ProductStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CartRepository, CART_INCLUDE } from './cart.repository';
import { CartItemRecord, serializeCart } from './cart.serializer';
import { AddCartItemDto } from './dto/cart.dto';

@Injectable()
export class CartService {
  constructor(
    private readonly repo: CartRepository,
    private readonly prisma: PrismaService,
  ) {}

  async getCart(userId: string) {
    const items = await this.repo.findItems(userId);
    return serializeCart(items as CartItemRecord[]);
  }

  /** Raw, included cart items — used by checkout to build the order. */
  async rawItems(userId: string): Promise<CartItemRecord[]> {
    return (await this.repo.findItems(userId)) as CartItemRecord[];
  }

  async addItem(userId: string, dto: AddCartItemDto) {
    const product = await this.prisma.product.findUnique({
      where: { id: dto.product_id },
      include: { variants: true },
    });
    if (!product) throw new NotFoundException('Product not found');
    if (product.status !== ProductStatus.ACTIVE) {
      throw new BadRequestException('Product is not available for purchase');
    }

    let availableStock = product.stock;
    if (dto.variant_id) {
      const variant = product.variants.find((v) => v.id === dto.variant_id);
      if (!variant) throw new NotFoundException('Variant not found');
      availableStock = variant.stock;
    }

    const quantity = dto.quantity ?? 1;
    const existing = await this.repo.findExisting(
      userId,
      dto.product_id,
      dto.variant_id ?? null,
    );
    const targetQty = (existing?.quantity ?? 0) + quantity;
    if (targetQty > availableStock) {
      throw new BadRequestException(
        availableStock === 0
          ? 'This item is out of stock'
          : `Only ${availableStock} in stock`,
      );
    }

    if (existing) {
      await this.repo.updateQuantity(existing.id, targetQty);
    } else {
      await this.prisma.cartItem.create({
        data: {
          userId,
          productId: dto.product_id,
          variantId: dto.variant_id ?? null,
          quantity,
        },
        include: CART_INCLUDE,
      });
    }
    return this.getCart(userId);
  }

  async updateItem(userId: string, id: string, quantity: number) {
    const item = await this.requireItem(userId, id);
    const stock = item.variant ? item.variant.stock : item.product.stock;
    if (quantity > stock) {
      throw new BadRequestException(`Only ${stock} in stock`);
    }
    await this.repo.updateQuantity(id, quantity);
    return this.getCart(userId);
  }

  async removeItem(userId: string, id: string) {
    await this.requireItem(userId, id);
    await this.repo.delete(id);
    return this.getCart(userId);
  }

  async clear(userId: string) {
    await this.repo.clear(userId);
    return this.getCart(userId);
  }

  private async requireItem(userId: string, id: string): Promise<CartItemRecord> {
    const item = await this.repo.findItem(id, userId);
    if (!item) throw new NotFoundException('Cart item not found');
    return item as CartItemRecord;
  }
}
