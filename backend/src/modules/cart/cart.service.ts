import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OfferStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CartRepository } from './cart.repository';
import {
  CartItemRecord,
  availableStockOf,
  serializeCart,
} from './cart.serializer';
import { AddCartItemDto } from './dto/cart.dto';

export type CartOwner =
  | { kind: 'user'; userId: string }
  | { kind: 'guest'; guestSessionId: string };

@Injectable()
export class CartService {
  constructor(
    private readonly repo: CartRepository,
    private readonly prisma: PrismaService,
  ) {}

  async getCart(owner: string | CartOwner) {
    const resolved = this.resolveOwner(owner);
    const items =
      resolved.kind === 'user'
        ? await this.repo.findItems(resolved.userId)
        : await this.repo.findGuestItems(resolved.guestSessionId);
    return serializeCart(items as CartItemRecord[]);
  }

  /** Raw, included cart items — used by checkout to build the order. */
  async rawItems(userId: string): Promise<CartItemRecord[]> {
    return (await this.repo.findItems(userId)) as CartItemRecord[];
  }

  async addItem(owner: string | CartOwner, dto: AddCartItemDto) {
    const resolved = this.resolveOwner(owner);
    const offer = await this.prisma.sellerOffer.findUnique({
      where: { id: dto.offer_id },
      include: { variants: true, product: { select: { status: true } } },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.status !== OfferStatus.ACTIVE || !offer.isActive) {
      throw new BadRequestException('This listing is not available right now');
    }

    let availableStock = offer.stock;
    if (dto.offer_variant_id) {
      const variant = offer.variants.find((v) => v.id === dto.offer_variant_id);
      if (!variant) throw new NotFoundException('Variant not found on this offer');
      availableStock = variant.stock;
    }

    const quantity = dto.quantity ?? 1;
    const existing =
      resolved.kind === 'user'
        ? await this.repo.findExisting(
            resolved.userId,
            dto.offer_id,
            dto.offer_variant_id ?? null,
          )
        : await this.repo.findGuestExisting(
            resolved.guestSessionId,
            dto.offer_id,
            dto.offer_variant_id ?? null,
          );
    const targetQty = (existing?.quantity ?? 0) + quantity;

    // Q33 P2 — sellers set their own minimum and maximum order quantity.
    if (targetQty < offer.minOrderQty) {
      throw new BadRequestException(
        `This seller requires at least ${offer.minOrderQty} per order`,
      );
    }
    if (offer.maxOrderQty && targetQty > offer.maxOrderQty) {
      throw new BadRequestException(
        `This seller allows at most ${offer.maxOrderQty} per order`,
      );
    }
    if (targetQty > availableStock) {
      throw new BadRequestException(
        availableStock === 0
          ? 'This item is out of stock'
          : `Only ${availableStock} in stock`,
      );
    }

    if (existing) {
      if (resolved.kind === 'user') {
        await this.repo.updateQuantity(existing.id, targetQty);
      } else {
        await this.repo.updateGuestQuantity(existing.id, targetQty);
      }
    } else if (resolved.kind === 'user') {
      await this.repo.create({
        userId: resolved.userId,
        offerId: dto.offer_id,
        offerVariantId: dto.offer_variant_id ?? null,
        quantity,
      });
    } else {
      await this.repo.createGuest({
        guestSessionId: resolved.guestSessionId,
        offerId: dto.offer_id,
        offerVariantId: dto.offer_variant_id ?? null,
        quantity,
      });
    }
    return this.getCart(resolved);
  }

  async updateItem(owner: string | CartOwner, id: string, quantity: number) {
    const resolved = this.resolveOwner(owner);
    const item = await this.requireItem(resolved, id);
    const stock = availableStockOf(item);
    if (quantity > stock) {
      throw new BadRequestException(`Only ${stock} in stock`);
    }
    if (resolved.kind === 'user') {
      await this.repo.updateQuantity(id, quantity);
    } else {
      await this.repo.updateGuestQuantity(id, quantity);
    }
    return this.getCart(resolved);
  }

  async removeItem(owner: string | CartOwner, id: string) {
    const resolved = this.resolveOwner(owner);
    await this.requireItem(resolved, id);
    if (resolved.kind === 'user') {
      await this.repo.delete(id);
    } else {
      await this.repo.deleteGuest(id);
    }
    return this.getCart(resolved);
  }

  async clear(owner: string | CartOwner) {
    const resolved = this.resolveOwner(owner);
    if (resolved.kind === 'user') {
      await this.repo.clear(resolved.userId);
    } else {
      await this.repo.clearGuest(resolved.guestSessionId);
    }
    return this.getCart(resolved);
  }

  private async requireItem(
    owner: CartOwner,
    id: string,
  ): Promise<CartItemRecord> {
    const item =
      owner.kind === 'user'
        ? await this.repo.findItem(id, owner.userId)
        : await this.repo.findGuestItem(id, owner.guestSessionId);
    if (!item) throw new NotFoundException('Cart item not found');
    return item as CartItemRecord;
  }

  private resolveOwner(owner: string | CartOwner): CartOwner {
    return typeof owner === 'string' ? { kind: 'user', userId: owner } : owner;
  }
}
