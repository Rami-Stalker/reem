import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  forwardRef,
} from '@nestjs/common';
import {
  Currency,
  FulfilmentMode,
  OfferStatus,
  OrderStatus,
  Prisma,
  RoundingPolicy,
  SellerOrderStatus,
} from '@prisma/client';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../../prisma/prisma.service';
import { serializeOrderDetail } from '../../common/serializers';
import { AppEvent } from '../../common/events/app-events';
import { Money } from '../../common/money';
import { CartService } from '../cart/cart.service';
import { CartItemRecord, unitPriceOf } from '../cart/cart.serializer';
import { DeliveryService } from '../delivery/delivery.service';
import { ShipmentsService } from '../delivery/shipments.service';
import { PaymentsService } from '../payments/payments.service';
import { CouponsService } from '../rewards/coupons.service';
import { MembershipService } from '../rewards/membership.service';
import { PointsService } from '../rewards/points.service';
import { ReferralsService } from '../rewards/referrals.service';
import { CommissionQuoteService } from '../commissions/commission-quote.service';
import { ExchangeRateService } from '../pricing/exchange-rate.service';
import { OrdersRepository } from './orders.repository';
import { CreateOrderDto, ShippingDetailsDto } from './dto/create-order.dto';
import { RETURN_WINDOW_DAYS } from '../returns/return-policy';

interface SellerGroup {
  sellerId: string;
  sellerName: string;
  lines: { item: CartItemRecord; unitPrice: Money }[];
  itemsSubtotal: Money;
  categorySlugs: string[];
  sellerTier: string;
}

/**
 * Checkout.
 *
 * One basket becomes one parent order (paid once, shipped once as far as the
 * customer's wallet is concerned) plus one sub-order per seller, each of which
 * is confirmed, prepared, shipped, cancelled, returned and settled on its own
 * timeline. The order-wide charges — the coupon and the shipping fee — are
 * *allocated* across the sub-orders by largest remainder so the children always
 * add back up to the parent exactly.
 */
@Injectable()
export class CheckoutService {
  private readonly logger = new Logger(CheckoutService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cart: CartService,
    // PaymentsService calls back into this service to confirm an order once a
    // gateway settles, so the pair is a deliberate cycle and both sides need
    // forwardRef — the module-level one alone is not enough.
    @Inject(forwardRef(() => PaymentsService))
    private readonly payments: PaymentsService,
    private readonly delivery: DeliveryService,
    private readonly shipments: ShipmentsService,
    private readonly coupons: CouponsService,
    private readonly points: PointsService,
    private readonly membership: MembershipService,
    private readonly referrals: ReferralsService,
    private readonly commissions: CommissionQuoteService,
    private readonly rates: ExchangeRateService,
    private readonly events: EventEmitter2,
    private readonly ordersRepo: OrdersRepository,
  ) {}

  async checkout(userId: string, dto: CreateOrderDto) {
    const items = await this.cart.rawItems(userId);
    if (items.length === 0) {
      throw new BadRequestException('Your cart is empty');
    }

    const shipping = await this.resolveShipping(userId, dto);
    const orderCurrency = dto.currency ?? (await this.preferredCurrency(userId));

    // 1. Freeze the rate BEFORE any price is read, so every figure on this
    //    order — including refunds computed months later — agrees (Q46 P2).
    const frozen = await this.rates.current(Currency.USD, orderCurrency);

    // 2. Validate each line and convert it into the order currency.
    const groups = await this.groupBySeller(items, orderCurrency);
    const itemsSubtotal = Money.sum(
      groups.map((group) => group.itemsSubtotal),
      orderCurrency,
    );

    // 3. Coupon, evaluated once against the whole basket.
    const coupon = dto.coupon_code
      ? await this.coupons.evaluate(dto.coupon_code, userId, itemsSubtotal)
      : null;
    const discountTotal = coupon?.discount ?? Money.zero(orderCurrency);

    // 4. One shipping charge for the whole order (Q65 P1), regardless of how
    //    many sellers are involved.
    const shippingQuote = await this.delivery.quote({
      governorate: shipping.governorate,
      district: shipping.district ?? null,
      isRural: shipping.is_rural ?? false,
      isExpress: dto.is_express ?? false,
      subtotal: itemsSubtotal,
    });
    const shippingTotal = this.rates.convert(
      shippingQuote.fee,
      orderCurrency,
      await this.rates.current(shippingQuote.fee.currency, orderCurrency),
    );

    const roundingPolicy =
      orderCurrency === Currency.SYP
        ? RoundingPolicy.NEAREST_1000
        : RoundingPolicy.NONE;

    const grandTotal = itemsSubtotal
      .minus(discountTotal)
      .plus(shippingTotal)
      .round(roundingPolicy);

    // 5. Split the order-wide charges across sellers, weighted by their share
    //    of the basket. Largest-remainder allocation guarantees the parts sum
    //    back to the whole — no stray unit left in either direction.
    const weights = groups.map((group) => group.itemsSubtotal.toPrisma());
    const discountShares = discountTotal.allocate(weights);
    const shippingShares = shippingTotal.allocate(weights);

    const number = this.orderNumber();

    const order = await this.prisma.$transaction(async (tx) => {
      const created = await tx.order.create({
        data: {
          number,
          userId,
          status: OrderStatus.PENDING_PAYMENT,
          currency: orderCurrency,
          fxRate: frozen.rate,
          fxRateId: frozen.rateId,
          fxFrozenAt: frozen.frozenAt,
          roundingPolicy,
          itemsSubtotal: itemsSubtotal.toPrisma(),
          discountTotal: discountTotal.toPrisma(),
          shippingTotal: shippingTotal.toPrisma(),
          grandTotal: grandTotal.toPrisma(),
          couponCode: coupon?.coupon.code ?? null,
          recipientName: shipping.recipient_name,
          recipientPhone: shipping.recipient_phone,
          governorate: shipping.governorate,
          district: shipping.district ?? null,
          city: shipping.city,
          addressLine: shipping.address_line,
          landmark: shipping.landmark ?? null,
          privacyMaskEnabled: dto.privacy_mask ?? false,
          deliveryInstructions: dto.delivery_instructions ?? null,
          notes: dto.notes ?? null,
          placedAt: new Date(),
          events: {
            create: [
              {
                title: 'Order created',
                description: `Order ${number} placed`,
                toStatus: OrderStatus.PENDING_PAYMENT,
                actorId: userId,
                actorRole: 'CUSTOMER',
              },
            ],
          },
        },
      });

      for (const [index, group] of groups.entries()) {
        const discountShare = discountShares[index];
        const shippingShare = shippingShares[index];

        // Q50 charges commission on the post-discount price — but only for a
        // discount the seller actually gave. Q49 P2 puts a platform coupon on
        // the platform, which means the seller sold at her full price and is
        // owed on it; leaving her base reduced would have made her pay for a
        // promotion somebody else ran. The gap between this base and what the
        // customer paid is what the platform put in, and settlement books it
        // as marketing spend.
        const sellerFundsDiscount = coupon?.coupon.fundedBySeller ?? true;
        const commissionBase = sellerFundsDiscount
          ? group.itemsSubtotal.minus(discountShare)
          : group.itemsSubtotal;
        const quote = await this.commissions.quote({
          sellerId: group.sellerId,
          sellerTier: group.sellerTier,
          categorySlugs: group.categorySlugs,
          base: commissionBase,
        });

        const sellerOrder = await tx.sellerOrder.create({
          data: {
            number: `${number}-${index + 1}`,
            orderId: created.id,
            sellerId: group.sellerId,
            status: SellerOrderStatus.NEW,
            fulfilmentMode: FulfilmentMode.PLATFORM_COURIER,
            currency: orderCurrency,
            itemsSubtotal: group.itemsSubtotal.toPrisma(),
            discountTotal: discountShare.toPrisma(),
            shippingCost: shippingShare.toPrisma(),
            commissionBase: commissionBase.toPrisma(),
            commissionAmount: quote.commission.toPrisma(),
            sellerNet: quote.net.toPrisma(),
            items: {
              create: group.lines.map(({ item, unitPrice }) => ({
                offerId: item.offerId,
                productId: item.offer.productId,
                variantId: item.offerVariant?.variantId ?? null,
                titleSnapshot: item.offer.product.title,
                imageSnapshot: item.offer.product.media[0]?.url ?? null,
                variantSnapshot: item.offerVariant?.variant.name ?? null,
                sellerSnapshot: group.sellerName,
                currency: orderCurrency,
                unitPrice: unitPrice.toPrisma(),
                lineTotal: unitPrice.times(item.quantity).toPrisma(),
                quantity: item.quantity,
              })),
            },
            events: {
              create: [
                {
                  title: 'Sub-order created',
                  description: `Awaiting confirmation from ${group.sellerName}`,
                  toStatus: SellerOrderStatus.NEW,
                  actorRole: 'SYSTEM',
                },
              ],
            },
          },
        });

        // Stock comes off the OFFER, and off the offer variant when one was
        // chosen — the canonical product has no stock to decrement.
        for (const { item } of group.lines) {
          await tx.sellerOffer.update({
            where: { id: item.offerId },
            data: { stock: { decrement: item.quantity } },
          });
          if (item.offerVariantId) {
            await tx.sellerOfferVariant.update({
              where: { id: item.offerVariantId },
              data: { stock: { decrement: item.quantity } },
            });
          }
          await tx.product.update({
            where: { id: item.offer.productId },
            data: { ordersCount: { increment: item.quantity } },
          });
        }

        void sellerOrder;
      }

      await tx.cartItem.deleteMany({ where: { userId } });
      return created;
    });

    // 6. Payment for the parent — the customer pays once (provider call stays
    //    outside the transaction).
    const { redirectUrl, requiresOnlineConfirmation } =
      await this.payments.initiateForOrder(
        order.id,
        order.number,
        grandTotal,
        dto.payment_method,
        userId,
      );

    if (!requiresOnlineConfirmation) {
      await this.confirm(order.id, userId);
    }

    if (coupon) {
      await this.coupons.recordRedemption(
        coupon.coupon.id,
        userId,
        order.id,
        discountTotal,
      );
    }
    await this.points.earn(
      userId,
      Math.floor(grandTotal.toUnsafeNumber()),
      'Order purchase',
      order.id,
    );
    await this.membership.recordPurchase(userId, order.id, grandTotal);
    await this.referrals.qualifyReferralForOrder(userId, order.id);

    this.events.emit(AppEvent.OrderStatusChanged, {
      userId,
      orderId: order.id,
      orderNumber: order.number,
      status: requiresOnlineConfirmation
        ? OrderStatus.PENDING_PAYMENT
        : OrderStatus.CONFIRMED,
    });

    const detail = await this.ordersRepo.findDetailById(order.id);
    return {
      order: serializeOrderDetail(detail!),
      redirect_url: redirectUrl,
      requires_online_confirmation: requiresOnlineConfirmation,
    };
  }

  /**
   * Moves a paid (or cash-on-delivery) order into the sellers' queues.
   *
   * The escrow clock deliberately does **not** start here. Q24 releases a
   * seller's earnings once the return window has closed, and Q56 counts that
   * window «من الاستلام» — from delivery, not from payment. Starting it at
   * confirmation paid sellers seven days after the customer's money arrived
   * even if the parcel was still on a shelf, and for a parcel that was never
   * delivered at all it would have paid them for nothing. It is set instead by
   * `SellerOrderWorkflowService` at the moment a parcel is marked delivered.
   */
  async confirm(orderId: string, actorId?: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await tx.order.update({
        where: { id: orderId },
        data: { status: OrderStatus.CONFIRMED },
      });
      await tx.sellerOrder.updateMany({
        where: { orderId, status: SellerOrderStatus.NEW },
        data: {
          status: SellerOrderStatus.AWAITING_SELLER_CONFIRMATION,
          confirmedAt: new Date(),
        },
      });
      await tx.orderEvent.create({
        data: {
          orderId,
          title: 'Order confirmed',
          description: 'Sent to the sellers for preparation',
          fromStatus: OrderStatus.PENDING_PAYMENT,
          toStatus: OrderStatus.CONFIRMED,
          actorId: actorId ?? null,
          actorRole: 'SYSTEM',
        },
      });

      await this.openShipments(tx, orderId);
    });
  }

  /**
   * Opens a parcel for every sub-order the platform is going to carry.
   *
   * Created at confirmation rather than when a seller marks the parcel ready,
   * because the customer expects a tracking code from the moment she pays
   * (Q64 «تتبع الشحنة للزبونة») — the parcel simply sits in CREATED until
   * someone picks it up.
   *
   * Only modes the platform actually moves get one. A seller shipping it
   * herself (Q57) or a customer collecting from a pickup point is not carrying
   * our cash, and inventing a shipment for either would put a courier's name
   * on a journey nobody made.
   */
  private async openShipments(tx: Prisma.TransactionClient, orderId: string) {
    const carried = await tx.sellerOrder.findMany({
      where: {
        orderId,
        fulfilmentMode: {
          in: [FulfilmentMode.PLATFORM_COURIER, FulfilmentMode.THIRD_PARTY_CARRIER],
        },
        shipment: null,
      },
      select: { id: true },
    });

    for (const sellerOrder of carried) {
      await this.shipments.createForSellerOrder(sellerOrder.id, {}, tx);
    }
  }

  // ── internals ───────────────────────────────────────────────────────────

  private async preferredCurrency(userId: string): Promise<Currency> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { preferredCurrency: true },
    });
    return user?.preferredCurrency ?? Currency.SYP;
  }

  private async groupBySeller(
    items: CartItemRecord[],
    orderCurrency: Currency,
  ): Promise<SellerGroup[]> {
    const bySeller = new Map<string, SellerGroup>();

    for (const item of items) {
      this.assertPurchasable(item);

      const listed = unitPriceOf(item);
      const rate = await this.rates.current(listed.currency, orderCurrency);
      const unitPrice = this.rates.convert(listed, orderCurrency, rate);

      const sellerId = item.offer.sellerId;
      const group = bySeller.get(sellerId) ?? {
        sellerId,
        sellerName: item.offer.seller.name,
        lines: [],
        itemsSubtotal: Money.zero(orderCurrency),
        categorySlugs: [],
        sellerTier: item.offer.seller.sellerLevel,
      };

      group.lines.push({ item, unitPrice });
      group.itemsSubtotal = group.itemsSubtotal.plus(
        unitPrice.times(item.quantity),
      );
      if (!group.categorySlugs.includes(item.offer.product.category.slug)) {
        group.categorySlugs.push(item.offer.product.category.slug);
      }
      bySeller.set(sellerId, group);
    }

    return [...bySeller.values()];
  }

  private assertPurchasable(item: CartItemRecord) {
    const title = item.offer.product.title;
    if (item.offer.status !== OfferStatus.ACTIVE || !item.offer.isActive) {
      throw new BadRequestException(`${title} is no longer available`);
    }
    const stock = item.offerVariant
      ? item.offerVariant.stock
      : item.offer.stock;
    if (item.quantity > stock) {
      throw new BadRequestException(`Only ${stock} left of ${title}`);
    }
    if (item.quantity < item.offer.minOrderQty) {
      throw new BadRequestException(
        `${title} has a minimum order of ${item.offer.minOrderQty}`,
      );
    }
    if (item.offer.maxOrderQty && item.quantity > item.offer.maxOrderQty) {
      throw new BadRequestException(
        `${title} has a maximum order of ${item.offer.maxOrderQty}`,
      );
    }
  }

  /**
   * Where this order is going.
   *
   * A saved address is read from the database rather than taken from the
   * request, even when the client helpfully sends both: the copy in the body
   * is whatever that build happened to render, and the only address she can be
   * said to have chosen is the one stored under her own id.
   *
   * Saving what she typed is opt-in and best-effort. A duplicate row or a
   * validation quibble in the address book must never be the reason an order
   * she has already paid attention to fails to place.
   */
  private async resolveShipping(
    userId: string,
    dto: CreateOrderDto,
  ): Promise<ShippingDetailsDto> {
    if (dto.address_id) {
      const saved = await this.prisma.address.findFirst({
        where: { id: dto.address_id, userId },
      });
      if (!saved) throw new NotFoundException('Address not found');

      return {
        recipient_name: saved.recipientName,
        recipient_phone: saved.recipientPhone,
        governorate: saved.governorate,
        district: saved.district ?? undefined,
        city: saved.city,
        address_line: saved.addressLine,
        landmark: saved.landmark ?? undefined,
        is_rural: saved.isRural,
      };
    }

    if (!dto.shipping) {
      throw new BadRequestException(
        'Choose a saved address or enter a delivery address',
      );
    }

    if (dto.save_address) {
      try {
        const isFirst =
          (await this.prisma.address.count({ where: { userId } })) === 0;
        await this.prisma.address.create({
          data: {
            userId,
            label: 'المنزل',
            recipientName: dto.shipping.recipient_name,
            recipientPhone: dto.shipping.recipient_phone,
            governorate: dto.shipping.governorate,
            district: dto.shipping.district ?? null,
            city: dto.shipping.city,
            addressLine: dto.shipping.address_line,
            landmark: dto.shipping.landmark ?? null,
            isRural: dto.shipping.is_rural ?? false,
            deliveryInstructions: dto.delivery_instructions ?? null,
            isDefault: isFirst,
          },
        });
      } catch (error) {
        this.logger.warn(
          `Could not save the address for ${userId}: ${(error as Error).message}`,
        );
      }
    }

    return dto.shipping;
  }

  private orderNumber(): string {
    const stamp = Date.now().toString(36).toUpperCase();
    const noise = Math.floor(Math.random() * 900 + 100);
    return `REEM-${stamp}${noise}`;
  }
}

/** Re-exported for the settlement job that releases escrow. */
export const ESCROW_WINDOW_DAYS = RETURN_WINDOW_DAYS;

export type CheckoutTransaction = Prisma.TransactionClient;
