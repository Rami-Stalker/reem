import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * The cart holds SELLER OFFERS, not bare products: price, currency, stock and
 * fulfilment terms are all properties of one seller's listing. This is also
 * what lets checkout group a basket into per-seller sub-orders without a
 * second round of lookups.
 */
const OFFER_LINE_INCLUDE = {
  seller: true,
  product: {
    include: { media: { orderBy: { sortOrder: 'asc' as const } }, category: true },
  },
  /**
   * Flash-sale lines, so `unitPriceOf` can charge the sale price.
   *
   * Filtered on status here and on the *window* in `flashSalePriceOf`, because
   * a window is a comparison against `now` and an include is a static shape.
   * Loading the handful of active-status rows and deciding in one function is
   * what keeps a single authority over price — the alternative is a time
   * comparison written into every query that ever needs a price.
   */
  flashSaleItems: {
    where: { sale: { status: 'ACTIVE' as const } },
    include: { sale: true },
  },
};

export const CART_INCLUDE = {
  offer: { include: OFFER_LINE_INCLUDE },
  offerVariant: { include: { variant: true } },
} satisfies Prisma.CartItemInclude;

export const GUEST_CART_INCLUDE = {
  offer: { include: OFFER_LINE_INCLUDE },
  offerVariant: { include: { variant: true } },
} satisfies Prisma.GuestCartItemInclude;

@Injectable()
export class CartRepository {
  constructor(private readonly prisma: PrismaService) {}

  findItems(userId: string) {
    return this.prisma.cartItem.findMany({
      where: { userId },
      include: CART_INCLUDE,
      orderBy: { createdAt: 'desc' },
    });
  }

  findGuestItems(guestSessionId: string) {
    return this.prisma.guestCartItem.findMany({
      where: { guestSessionId },
      include: GUEST_CART_INCLUDE,
      orderBy: { createdAt: 'desc' },
    });
  }

  findItem(id: string, userId: string) {
    return this.prisma.cartItem.findFirst({
      where: { id, userId },
      include: CART_INCLUDE,
    });
  }

  findGuestItem(id: string, guestSessionId: string) {
    return this.prisma.guestCartItem.findFirst({
      where: { id, guestSessionId },
      include: GUEST_CART_INCLUDE,
    });
  }

  findExisting(userId: string, offerId: string, offerVariantId: string | null) {
    return this.prisma.cartItem.findFirst({
      where: { userId, offerId, offerVariantId },
    });
  }

  findGuestExisting(
    guestSessionId: string,
    offerId: string,
    offerVariantId: string | null,
  ) {
    return this.prisma.guestCartItem.findFirst({
      where: { guestSessionId, offerId, offerVariantId },
    });
  }

  create(data: Prisma.CartItemUncheckedCreateInput) {
    return this.prisma.cartItem.create({ data });
  }

  createGuest(data: Prisma.GuestCartItemUncheckedCreateInput) {
    return this.prisma.guestCartItem.create({ data });
  }

  updateQuantity(id: string, quantity: number) {
    return this.prisma.cartItem.update({ where: { id }, data: { quantity } });
  }

  updateGuestQuantity(id: string, quantity: number) {
    return this.prisma.guestCartItem.update({
      where: { id },
      data: { quantity },
    });
  }

  delete(id: string) {
    return this.prisma.cartItem.delete({ where: { id } });
  }

  deleteGuest(id: string) {
    return this.prisma.guestCartItem.delete({ where: { id } });
  }

  clear(userId: string) {
    return this.prisma.cartItem.deleteMany({ where: { userId } });
  }

  clearGuest(guestSessionId: string) {
    return this.prisma.guestCartItem.deleteMany({ where: { guestSessionId } });
  }
}
