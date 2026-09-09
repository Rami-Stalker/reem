import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OfferStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { TrendSignalService } from '../trends/collection/trend-signal.service';
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
    private readonly signals: TrendSignalService,
  ) {}

  async getCart(owner: string | CartOwner) {
    const resolved = this.resolveOwner(owner);
    const items =
      resolved.kind === 'user'
        ? await this.repo.findItems(resolved.userId)
        : await this.repo.findGuestItems(resolved.guestSessionId);
    return serializeCart(items as CartItemRecord[]);
  }

  /**
   * Raw, included cart items — used by checkout to build the order.
   *
   * Takes an owner rather than a user id because a guest's basket is a real
   * basket: Q46 P1 lets her buy, and until now checkout could only read the
   * `cart_items` table, so everything she had put in `guest_cart_items` was
   * unreachable from the till.
   */
  async rawItems(owner: string | CartOwner): Promise<CartItemRecord[]> {
    const resolved = this.resolveOwner(owner);
    const items =
      resolved.kind === 'user'
        ? await this.repo.findItems(resolved.userId)
        : await this.repo.findGuestItems(resolved.guestSessionId);
    return items as CartItemRecord[];
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

    // The strongest pre-purchase intent signal there is, and the one the
    // `cart_items` table cannot supply on its own: those rows are deleted at
    // checkout, so counting them would under-report by exactly the adds that
    // converted.
    this.signals.recordCartAdd({
      productId: offer.productId,
      sellerId: offer.sellerId,
      userId: resolved.kind === 'user' ? resolved.userId : null,
      quantity,
    });

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
    const item = await this.requireItem(resolved, id);
    // Netted against the adds, so a woman who changed her mind is not counted
    // as demand that the seller then fails to convert.
    this.signals.recordCartRemove({
      productId: item.offer.productId,
      sellerId: item.offer.sellerId,
      userId: resolved.kind === 'user' ? resolved.userId : null,
    });
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
