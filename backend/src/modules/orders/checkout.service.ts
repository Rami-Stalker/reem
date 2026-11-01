import { randomInt } from 'crypto';
import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  forwardRef,
} from '@nestjs/common';
import {
  CodAssurance,
  CodAssuranceState,
  Currency,
  FulfilmentMode,
  OfferStatus,
  OrderStatus,
  PaymentMethodType,
  Prisma,
  RoundingPolicy,
  SellerOrderStatus,
} from '@prisma/client';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../../prisma/prisma.service';
import { serializeOrderDetail } from '../../common/serializers';
import { AppEvent } from '../../common/events/app-events';
import { Money, SYP_ROUNDING } from '../../common/money';
import { CartService } from '../cart/cart.service';
import { PurchasableLine, unitPriceOf } from '../cart/cart.serializer';
import { DropsService } from '../market/drops/drops.service';
import { DeliveryService } from '../delivery/delivery.service';
import { ShipmentsService } from '../delivery/shipments.service';
import { PaymentsService } from '../payments/payments.service';
import { CouponsService } from '../rewards/coupons.service';
import { ScopedLine, eligibleBySeller } from '../rewards/coupon-scope';
import { ReferralsService } from '../rewards/referrals.service';
import { OrderEventCopy } from '../../common/orders/order-event-copy';
import { CommissionQuoteService } from '../commissions/commission-quote.service';
import {
  ExchangeRateService,
  FrozenRate,
} from '../pricing/exchange-rate.service';
import {
  CodAssessment,
  CodTrustService,
  customerMessageFor,
} from '../cod-trust/cod-trust.service';
import { OrdersRepository } from './orders.repository';
import { CreateOrderDto, ShippingDetailsDto } from './dto/create-order.dto';
import { RETURN_WINDOW_DAYS } from '../returns/return-policy';
import { Buyer, guestSessionIdOf, ownedByBuyer, userIdOf } from './buyer';
import { expiryFor } from './order-expiry';
import { InventoryReservationService } from './workflow/inventory-reservation.service';
import { claimFlashSaleUnits } from './workflow/stock-claim';
import { pinOf } from '../../common/geo/pin';

interface SellerGroup {
  sellerId: string;
  sellerName: string;
  lines: { item: PurchasableLine; unitPrice: Money }[];
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
    private readonly referrals: ReferralsService,
    private readonly commissions: CommissionQuoteService,
    private readonly rates: ExchangeRateService,
    private readonly events: EventEmitter2,
    private readonly ordersRepo: OrdersRepository,
    private readonly codTrust: CodTrustService,
    private readonly drops: DropsService,
    private readonly reservations: InventoryReservationService,
  ) {}

  /**
   * The cart's door into checkout.
   *
   * Kept exactly as it was, and now one of two: Ohara Rooms buys through
   * [checkoutLines] with a plan's own lines, never by filling the cart first.
   * Two doors, one till — see the section comment in `schema.prisma`.
   */
  async checkout(buyer: Buyer, dto: CreateOrderDto) {
    const items = await this.cart.rawItems(buyer);
    if (items.length === 0) {
      throw new BadRequestException('Your cart is empty');
    }
    return this.checkoutLines(buyer, dto, items, { clearCart: true });
  }

  /**
   * Place an order from lines the caller assembled.
   *
   * `clearCart` is false for a plan, and that is the whole reason this
   * parameter exists: emptying a woman's cart because she bought something out
   * of a room would be the room reaching into a place it has nothing to do
   * with. It stays true for the cart path, where clearing is the correct
   * behaviour and the behaviour that has always happened.
   */
  async checkoutLines(
    buyer: Buyer,
    dto: CreateOrderDto,
    items: PurchasableLine[],
    options: { clearCart?: boolean } = {},
  ) {
    if (items.length === 0) {
      throw new BadRequestException('There is nothing to buy');
    }
    // Before anything is priced or held: a rail she could not finish paying
    // on would only produce an order that expires.
    this.payments.assertAvailable(dto.payment_method);

    // Null for a guest, and threaded rather than branched on at every call:
    // most of what follows either takes a nullable id already or is skipped
    // wholesale for a guest, and the two cases are named where they differ.
    const userId = userIdOf(buyer);

    const { shipping, fromAddressBook } = await this.resolveShipping(buyer, dto);
    const orderCurrency = dto.currency ?? (await this.preferredCurrency(buyer));

    // 1. Freeze the rate BEFORE any price is read, so every figure on this
    //    order — including refunds computed months later — agrees (Q46 P2).
    const frozen = await this.rates.current(Currency.USD, orderCurrency);

    // 2. Validate each line and convert it into the order currency.
    const groups = await this.groupBySeller(items, orderCurrency, frozen);
    const itemsSubtotal = Money.sum(
      groups.map((group) => group.itemsSubtotal),
      orderCurrency,
    );

    // 3. Coupon, evaluated once against the whole basket.
    //
    // Not for a guest, and refused rather than ignored. A coupon's limits are
    // *per account* — `perUserLimit`, and a redemption row that names a user —
    // so honouring one for a session that costs nothing to create would make
    // every single-use code infinitely reusable. Telling her to sign in is the
    // honest answer; silently dropping the discount would charge her more than
    // the screen said.
    if (dto.coupon_code && buyer.kind === 'guest') {
      throw new BadRequestException({
        code: 'COUPON_REQUIRES_ACCOUNT',
        message: 'سجّلي الدخول لاستخدام الكوبون',
      });
    }
    // The basket, flattened to what a coupon needs to judge each line. Passing
    // it is what makes a scoped code discount only the part it covers rather
    // than the whole subtotal.
    const scopedLines: ScopedLine[] = groups.flatMap((group) =>
      group.lines.map(({ item, unitPrice }) => ({
        sellerId: group.sellerId,
        productId: item.offer.productId,
        categoryId: item.offer.product.categoryId,
        lineTotal: unitPrice.times(item.quantity),
      })),
    );

    // One field, two kinds of code.
    //
    // «كود الدعوة» and «الكوبون» are the same box on her screen, and she has
    // no way of knowing which one she is holding — a friend sends her a code
    // and she types it where codes go. So an unrecognised code is checked
    // against the live invite codes before it is refused: if it is one, the
    // referral is recorded and the welcome discount it mints is what this
    // checkout then applies. Applying a code and getting the discount it
    // promised become one action, which is what she expected all along.
    const couponCode = dto.coupon_code && userId
      ? await this.resolveCouponCode(dto.coupon_code, userId)
      : null;

    const coupon =
      couponCode && userId
        ? await this.coupons.evaluate(
            couponCode,
            userId,
            itemsSubtotal,
            scopedLines,
          )
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
    const quotedShipping = this.rates
      .convert(
        shippingQuote.fee,
        orderCurrency,
        await this.rates.current(shippingQuote.fee.currency, orderCurrency),
      )
      .quantize();

    const roundingPolicy =
      orderCurrency === Currency.SYP ? SYP_ROUNDING : RoundingPolicy.NONE;

    const { grandTotal, shippingTotal } = this.roundTotal(
      itemsSubtotal,
      discountTotal,
      quotedShipping,
      roundingPolicy,
    );

    // Wallet credit is spent after the order is written, because the debit
    // and the payment row belong together. Checked here first so a basket
    // she cannot afford is refused before it takes stock off the shelf, burns
    // her coupon and empties her cart — the debit itself still re-checks
    // under the wallet's row lock, so this is a courtesy, not the guard.
    if (dto.payment_method === PaymentMethodType.PLATFORM_WALLET) {
      await this.assertWalletCovers(userId, grandTotal);
    }

    // 5. Cash going out on the road is assessed before anything is written.
    //    A decision taken after the sellers have been told to prepare a parcel
    //    is not a decision, it is a report — and the top of the ladder has to
    //    be able to stop this basket from becoming a cash order at all.
    const codAssessment = await this.assessCashRisk({
      userId,
      dto,
      shipping,
      fromAddressBook,
      groups,
      grandTotal,
      usdRate: frozen.rate,
    });

    // 6. Split the order-wide charges across sellers, weighted by their share
    //    of the basket. Largest-remainder allocation guarantees the parts sum
    //    back to the whole — no stray unit left in either direction.
    const weights = groups.map((group) => group.itemsSubtotal.toPrisma());
    // Shipping is an order-wide charge and splits by basket share. The
    // discount does not: a code scoped to one boutique must land entirely on
    // that boutique's parcel, or the other sellers' commission bases are
    // reduced for a promotion they had no part in — which is precisely what
    // used to happen, invisibly, on every seller-funded code.
    const discountWeights = coupon
      ? eligibleBySeller(
          coupon.coupon,
          scopedLines,
          groups.map((group) => group.sellerId),
          itemsSubtotal,
        ).map((share) => share.toPrisma())
      : weights;
    const discountShares = discountTotal.allocate(discountWeights);
    const shippingShares = shippingTotal.allocate(weights);

    const number = this.orderNumber();

    // One instant for the whole order: `placedAt` and the deadline derived
    // from it must not straddle a millisecond boundary, or an order can appear
    // to have been created after its own expiry.
    const placedAt = new Date();
    // Shared by the order row and every reservation it takes, so the basket
    // and the units it is holding expire together.
    const expiresAt = expiryFor(dto.payment_method, placedAt);

    const order = await this.prisma.$transaction(async (tx) => {
      const created = await tx.order.create({
        data: {
          number,
          userId,
          // Exactly one of the two is set. This column has existed, indexed,
          // since the schema was written and nothing ever wrote to it — which
          // is what made a guest's order unreachable to the guest who placed
          // it. It is her only claim on the order afterwards.
          guestSessionId: guestSessionIdOf(buyer),
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
          ...pinOf(shipping),
          privacyMaskEnabled: dto.privacy_mask ?? false,
          deliveryInstructions: dto.delivery_instructions ?? null,
          notes: dto.notes ?? null,
          placedAt,
          // The stock is already off the shelf by the end of this
          // transaction. This is when it goes back if nobody pays. See
          // `order-expiry.ts` for why the window depends on the rail.
          expiresAt,
          events: {
            create: [
              {
                title: OrderEventCopy.orderCreated,
                description: OrderEventCopy.orderPlaced(number),
                toStatus: OrderStatus.PENDING_PAYMENT,
                // Null for a guest: the timeline records that a customer
                // placed it, and there is no account to name.
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
                  title: OrderEventCopy.subOrderCreated,
                  description: OrderEventCopy.awaitingSeller(group.sellerName),
                  toStatus: SellerOrderStatus.NEW,
                  actorRole: 'SYSTEM',
                },
              ],
            },
          },
        });

        // Stock comes off the OFFER, and off the offer variant when one was
        // chosen — the canonical product has no stock to decrement. The claim
        // refuses rather than overselling, and now records *who* took the
        // units and when the hold lapses, so releasing them later is an
        // idempotent state change rather than a blind increment.
        for (const { item } of group.lines) {
          await this.reservations.reserve(tx, {
            orderId: created.id,
            sellerOrderId: sellerOrder.id,
            offerId: item.offerId,
            offerVariantId: item.offerVariantId ?? null,
            quantity: item.quantity,
            title: item.offer.product.title,
            // The same deadline the order carries. Two clocks for one hold
            // would eventually disagree about when the dress goes back on
            // sale, and the seller would have no way to tell which was right.
            expiresAt: expiresAt,
          });
          // A line priced by a live flash sale is counted against it, so the
          // sale can end when its units are gone. Not an error when it does:
          // see `claimFlashSaleUnits` for why the cap is soft.
          await claimFlashSaleUnits(tx, {
            offerId: item.offerId,
            quantity: item.quantity,
          });
          await tx.product.update({
            where: { id: item.offer.productId },
            data: { ordersCount: { increment: item.quantity } },
          });
        }

      }

      // Written inside the same transaction as the order it gated: an order
      // that exists without the reasoning that let it exist is a gap somebody
      // would otherwise have to fill in from memory months later.
      if (codAssessment) {
        await this.codTrust.record(tx, {
          orderId: created.id,
          userId,
          assessment: codAssessment,
          state:
            codAssessment.decision.assurance === CodAssurance.ORDER_CONFIRMATION
              ? CodAssuranceState.PENDING
              : CodAssuranceState.NOT_REQUIRED,
        });
      }

      // The coupon is claimed with the order, not after it. See
      // `CouponsService.redeemInTransaction` for what recording it afterwards
      // cost: a crash in the gap, or ten simultaneous baskets, and a
      // single-use code has funded all of them.
      if (coupon && userId) {
        await this.coupons.redeemInTransaction(
          tx,
          coupon.coupon.id,
          userId,
          created.id,
          discountTotal,
        );
      }

      if (options.clearCart) {
        // Whichever basket she was actually shopping from. Emptying
        // `cart_items` for a guest cleared nothing, which would have left her
        // guest basket full of goods she had just bought.
        if (buyer.kind === 'user') {
          await tx.cartItem.deleteMany({ where: { userId: buyer.userId } });
        } else {
          await tx.guestCartItem.deleteMany({
            where: { guestSessionId: buyer.guestSessionId },
          });
        }
      }
      return created;
    });

    // 7. Payment for the parent — the customer pays once (provider call stays
    //    outside the transaction).
    const { redirectUrl, requiresOnlineConfirmation } =
      await this.payments.initiateForOrder(
        order.id,
        order.number,
        grandTotal,
        dto.payment_method,
        userId,
      );

    // A cash order awaiting its code is held exactly where an unpaid online
    // order is held: no sellers told, no stock committed to a courier, no
    // parcel opened. The two reach `CONFIRMED` through different proofs and
    // the same door.
    const heldForConfirmation =
      codAssessment?.decision.assurance === CodAssurance.ORDER_CONFIRMATION;

    if (!requiresOnlineConfirmation && !heldForConfirmation) {
      await this.confirm(order.id, userId);
    }

    const codAssurance = heldForConfirmation
      ? await this.beginCodConfirmation(order, codAssessment!, userId)
      : null;

    // Everything below this line belongs to an account, and a guest has none:
    // points accrue to a balance, a tier is a history, a referral names two
    // people, and a drop's audience is a list of invited accounts. Skipped
    // rather than faked — Q46 P1 lets her buy without an account, and the
    // reward for opening one is precisely this.
    //
    // Points, the tier's bonus and cashback, and a referral's reward are *not*
    // given here any more. They used to be — on an order nobody had paid for
    // yet, which could be cancelled a minute later or left to expire, and
    // nothing ever took them back. Points convert into wallet credit, so that
    // was spendable money for a purchase that never happened; and the points
    // given here were given a second time, with the liability actually booked,
    // when the return window closed. Q43 says when they count: «بعد انتهاء
    // مدة الاسترجاع». `PurchaseRewardsService` grants all of it then, once,
    // on what she actually kept.

    // A drop's conversion is a purchase, by somebody it invited, of something
    // it carries. Recorded here rather than inferred later, because the only
    // moment the three facts are together is this one. Failure is swallowed:
    // a measurement must never cost a woman her order. A guest was invited to
    // nothing, so there is no conversion to attribute.
    if (userId) {
      try {
        await this.drops.markConverted(
          userId,
          items.map((item) => item.offer.productId),
        );
      } catch (error) {
        this.logger.warn(`Drop conversion not recorded: ${String(error)}`);
      }
    }

    // The analytics funnel's last step. Emitted here, at the one place an
    // order is born, rather than accepted from a phone: a conversion rate a
    // client can post to is a number a competitor can write.
    this.events.emit(AppEvent.OrderPlaced, {
      userId: userId ?? null,
      orderId: order.id,
    });

    this.events.emit(AppEvent.OrderStatusChanged, {
      userId,
      orderId: order.id,
      orderNumber: order.number,
      status:
        requiresOnlineConfirmation || heldForConfirmation
          ? OrderStatus.PENDING_PAYMENT
          : OrderStatus.CONFIRMED,
    });

    const detail = await this.ordersRepo.findDetailById(order.id);
    return {
      order: serializeOrderDetail(detail!),
      redirect_url: redirectUrl,
      requires_online_confirmation: requiresOnlineConfirmation,
      cod_assurance: codAssurance,
    };
  }

  /**
   * Releases a held cash order once the code has been read back.
   *
   * The code proves a live human at the delivery number is expecting a courier
   * with a bill. That is all it proves, and all it is asked to prove — it
   * grants no session and verifies no account.
   */
  async confirmCod(buyer: Buyer, orderId: string, code?: string) {
    const userId = userIdOf(buyer);
    const order = await this.prisma.order.findFirst({
      // Scoped to whoever owns the order — her account, or the guest session
      // she placed it from. A guest holding a code for somebody else's order
      // finds nothing here.
      where: { id: orderId, ...ownedByBuyer(buyer) },
      select: {
        id: true,
        number: true,
        status: true,
        recipientPhone: true,
      },
    });
    if (!order) throw new NotFoundException('Order not found');

    if (order.status !== OrderStatus.PENDING_PAYMENT) {
      // Already confirmed, cancelled, or moved on. Re-entering a code cannot
      // walk an order backwards.
      throw new BadRequestException('This order is not awaiting confirmation');
    }

    const shouldConfirm = await this.codTrust.satisfyConfirmation({
      orderId: order.id,
      recipientPhone: order.recipientPhone,
      code,
      actorId: userId,
    });

    if (shouldConfirm) {
      await this.confirm(order.id, userId);
      this.events.emit(AppEvent.OrderStatusChanged, {
        userId,
        orderId: order.id,
        orderNumber: order.number,
        status: OrderStatus.CONFIRMED,
      });
    }

    const detail = await this.ordersRepo.findDetailById(order.id);
    return { order: serializeOrderDetail(detail!) };
  }

  /** Re-sends the confirmation code for a held cash order. */
  async resendCodConfirmation(buyer: Buyer, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: {
        id: orderId,
        ...ownedByBuyer(buyer),
        status: OrderStatus.PENDING_PAYMENT,
      },
      select: { id: true, number: true, recipientPhone: true },
    });
    if (!order) throw new NotFoundException('Order not found');

    return this.codTrust.requestConfirmation({
      orderId: order.id,
      orderNumber: order.number,
      recipientPhone: order.recipientPhone,
      userId: userIdOf(buyer),
    });
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
  async confirm(
    orderId: string,
    actorId?: string | null,
    tx?: Prisma.TransactionClient,
  ): Promise<void> {
    const run = async (tx: Prisma.TransactionClient) => {
      // Only an order still waiting for its payment moves. One that expired
      // or was cancelled has already put its stock back, and confirming it
      // would send sellers to pack goods that are on sale to someone else.
      // One already confirmed is left as it is, so a repeated confirmation
      // (a retried request, a second proof of the same payment) is harmless.
      const claimed = await tx.order.updateMany({
        where: { id: orderId, status: OrderStatus.PENDING_PAYMENT },
        data: { status: OrderStatus.CONFIRMED },
      });
      if (claimed.count === 0) {
        const current = await tx.order.findUnique({
          where: { id: orderId },
          select: { status: true },
        });
        if (current && current.status !== OrderStatus.CANCELLED) return;
        throw new BadRequestException({
          code: 'ORDER_NOT_AWAITING_PAYMENT',
          message: 'This order is no longer waiting for payment',
        });
      }
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
          title: OrderEventCopy.orderConfirmed,
          description: OrderEventCopy.sentToSellers,
          fromStatus: OrderStatus.PENDING_PAYMENT,
          toStatus: OrderStatus.CONFIRMED,
          actorId: actorId ?? null,
          actorRole: 'SYSTEM',
        },
      });

      // The hold becomes a commitment. Clearing its deadline is the point:
      // from here a seller is packing these goods, and no sweep may put them
      // back on the shelf underneath her. Only a cancellation can, and that
      // goes through `restock`.
      await this.reservations.commit(tx, orderId);

      await this.openShipments(tx, orderId);
    };

    if (tx) return run(tx);
    await this.prisma.$transaction(run);
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

  /**
   * Scores the basket when — and only when — a courier will be carrying its
   * value in cash.
   *
   * A prepaid order is not assessed at all. There is nothing on the road to
   * lose, so reading a customer's delivery history to decide how to treat her
   * would be surveillance with no purpose behind it.
   *
   * The top of the ladder throws. That is not a refusal to sell: the same
   * basket goes through on any other rail, and the message says so. What it
   * refuses is to send three hundred dollars of another woman's stock out on
   * credit to a customer who has already sent three parcels back.
   */
  private async assessCashRisk(input: {
    /** Null for a guest — the engine already weighs that as its own signal. */
    userId: string | null;
    dto: CreateOrderDto;
    shipping: ShippingDetailsDto;
    fromAddressBook: boolean;
    groups: SellerGroup[];
    grandTotal: Money;
    usdRate: Prisma.Decimal;
  }): Promise<CodAssessment | null> {
    if (!CodTrustService.isCashRail(input.dto.payment_method)) return null;

    // `usdRate` converts USD into the order's currency, so dividing recovers
    // the dollar figure — the only unit in which a basket from March and a
    // basket from September are comparable.
    const orderValueUsd = input.usdRate.isZero()
      ? 0
      : input.grandTotal.toPrisma().dividedBy(input.usdRate).toNumber();

    const lines = input.groups.flatMap((group) => group.lines);

    const assessment = await this.codTrust.assess({
      userId: input.userId,
      destination: {
        governorate: input.shipping.governorate,
        addressLine: input.shipping.address_line,
        landmark: input.shipping.landmark ?? null,
        isRural: input.shipping.is_rural ?? false,
        recipientPhone: input.shipping.recipient_phone,
        fromAddressBook: input.fromAddressBook,
      },
      basket: {
        orderValueUsd,
        sellerCount: input.groups.length,
        itemCount: lines.reduce((total, line) => total + line.item.quantity, 0),
        maxUnitsOnOneLine: lines.reduce(
          (most, line) => Math.max(most, line.item.quantity),
          0,
        ),
      },
    });

    if (assessment.decision.assurance === CodAssurance.PREPAYMENT) {
      // Nothing is written for a basket that never became an order — the
      // assessment table holds assessments *of orders*. The decision itself
      // still has to be answerable for, so it goes to the audit log.
      await this.codTrust.auditDecision({
        orderId: '',
        orderNumber: '',
        userId: input.userId,
        assessment,
      });
      throw new BadRequestException({
        code: 'COD_UNAVAILABLE',
        message: customerMessageFor(CodAssurance.PREPAYMENT, []),
      });
    }

    return assessment;
  }

  /**
   * Sends the code and describes the hold to the client, in that order.
   *
   * A failure to dispatch must not strand a placed order in a state nobody can
   * leave, so the block is returned either way and the client is told to ask
   * for a resend.
   */
  private async beginCodConfirmation(
    order: { id: string; number: string; recipientPhone: string },
    assessment: CodAssessment,
    userId: string | null,
  ) {
    await this.codTrust.auditDecision({
      orderId: order.id,
      orderNumber: order.number,
      userId,
      assessment,
    });

    const message = customerMessageFor(
      assessment.decision.assurance,
      assessment.decision.ruleCodes,
    );

    try {
      const challenge = await this.codTrust.requestConfirmation({
        orderId: order.id,
        orderNumber: order.number,
        recipientPhone: order.recipientPhone,
        userId,
      });
      return { required: 'order_confirmation', message, ...challenge };
    } catch (error) {
      this.logger.error(
        `Could not send the COD confirmation for ${order.number}: ${
          (error as Error).message
        }`,
      );
      return {
        required: 'order_confirmation',
        message,
        dispatch_failed: true,
      };
    }
  }

  /**
   * The amount she is charged, and the delivery line that makes it add up.
   *
   * The total is rounded (Q48), and the parts it is rounded from used to be
   * stored unrounded beside it. So the order's own lines did not sum to its
   * total, and neither did its sub-orders: a few pounds a basket were charged
   * at checkout, settled nowhere, and refunded to nobody — the books carried
   * them as an unexplained remainder on the gateway receivable or a courier's
   * float, and a full cancellation refunded her a different figure from the
   * one she paid.
   *
   * The difference now lives on the delivery charge, the one order-wide line
   * the platform itself sets, so goods − discount + delivery is the total to
   * the last unit, and every sub-order, settlement and refund inherits that.
   * Rounding down is only taken when the delivery charge can absorb it;
   * otherwise the total rounds up, so no line is ever negative.
   */
  private roundTotal(
    itemsSubtotal: Money,
    discountTotal: Money,
    quotedShipping: Money,
    policy: RoundingPolicy,
  ): { grandTotal: Money; shippingTotal: Money } {
    const raw = itemsSubtotal.minus(discountTotal).plus(quotedShipping);
    if (raw.isNegative()) {
      // Coupons are clamped to the basket, so this is a bug upstream rather
      // than a basket — and charging a negative amount would pay her to shop.
      throw new BadRequestException('This order would total less than nothing');
    }

    let grandTotal = raw.round(policy);
    if (quotedShipping.plus(grandTotal.minus(raw)).isNegative()) {
      grandTotal = raw.roundUp(policy);
    }
    return {
      grandTotal,
      shippingTotal: quotedShipping.plus(grandTotal.minus(raw)),
    };
  }

  /** Refuses a wallet checkout the balance cannot cover. */
  private async assertWalletCovers(
    userId: string | null,
    grandTotal: Money,
  ): Promise<void> {
    if (!userId) {
      throw new BadRequestException('الدفع من المحفظة يحتاج تسجيل الدخول');
    }
    const wallet = await this.prisma.wallet.findUnique({
      where: { userId_currency: { userId, currency: grandTotal.currency } },
      select: { balance: true, frozen: true },
    });
    if (wallet?.frozen) {
      throw new BadRequestException({
        code: 'WALLET_FROZEN',
        message: 'محفظتكِ موقوفة مؤقتاً، اختاري طريقة دفع تانية',
      });
    }
    const balance = Money.of(wallet?.balance ?? 0, grandTotal.currency);
    if (grandTotal.greaterThan(balance)) {
      throw new BadRequestException({
        code: 'INSUFFICIENT_WALLET_BALANCE',
        message: `رصيد محفظتكِ (${balance.toString()}) ما بيكفي لهالطلب (${grandTotal.toString()})، اختاري طريقة دفع تانية`,
      });
    }
  }

  /** A guest has no stored preference, so the platform's own currency. */
  private async preferredCurrency(buyer: Buyer): Promise<Currency> {
    if (buyer.kind === 'guest') return Currency.SYP;
    const user = await this.prisma.user.findUnique({
      where: { id: buyer.userId },
      select: { preferredCurrency: true },
    });
    return user?.preferredCurrency ?? Currency.SYP;
  }

  private async groupBySeller(
    items: PurchasableLine[],
    orderCurrency: Currency,
    frozen: FrozenRate,
  ): Promise<SellerGroup[]> {
    const bySeller = new Map<string, SellerGroup>();
    // One rate per currency for the whole basket, starting from the one the
    // order freezes. Looked up per line, a rate published mid-checkout would
    // price half the basket at one rate and record the other as frozen.
    const rates = new Map<Currency, FrozenRate>([[frozen.base, frozen]]);

    for (const item of items) {
      this.assertPurchasable(item);

      const listed = unitPriceOf(item);
      const rate =
        rates.get(listed.currency) ??
        (await this.rates.current(listed.currency, orderCurrency));
      rates.set(listed.currency, rate);
      // Quantized to what the column keeps, so the line total, the seller's
      // subtotal and the order's subtotal are computed from the same figure
      // that is stored — a converted price otherwise runs to twenty places
      // and each total rounds on its own.
      const unitPrice = this.rates.convert(listed, orderCurrency, rate).quantize();

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

  private assertPurchasable(item: PurchasableLine) {
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
    buyer: Buyer,
    dto: CreateOrderDto,
  ): Promise<{ shipping: ShippingDetailsDto; fromAddressBook: boolean }> {
    const userId = userIdOf(buyer);

    if (dto.address_id) {
      // A guest has no address book, so an id from one is not hers. Refused as
      // "not found" rather than "not yours": the two answers together would
      // tell an unauthenticated caller which address ids exist.
      if (!userId) throw new NotFoundException('Address not found');
      const saved = await this.prisma.address.findFirst({
        where: { id: dto.address_id, userId },
      });
      if (!saved) throw new NotFoundException('Address not found');

      return {
        shipping: {
          recipient_name: saved.recipientName,
          recipient_phone: saved.recipientPhone,
          governorate: saved.governorate,
          district: saved.district ?? undefined,
          city: saved.city,
          address_line: saved.addressLine,
          landmark: saved.landmark ?? undefined,
          latitude: saved.latitude,
          longitude: saved.longitude,
          is_rural: saved.isRural,
        },
        // An address she has used before is a address a courier has found
        // before. That is worth something to the risk score, and it is knowledge
        // only this branch has.
        fromAddressBook: true,
      };
    }

    if (!dto.shipping) {
      throw new BadRequestException(
        'Choose a saved address or enter a delivery address',
      );
    }

    // `save_address` is silently a no-op for a guest rather than a refusal:
    // there is no address book to save into, and an order must never fail over
    // a convenience the client offered without knowing who was signed in.
    if (dto.save_address && userId) {
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
            ...pinOf(dto.shipping),
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

    return { shipping: dto.shipping, fromAddressBook: false };
  }

  /**
   * The code she typed, turned into a coupon code the rail can evaluate.
   *
   * Returns the code unchanged when it already names a coupon. When it does
   * not, it is looked up as an invite: a live one is applied — which records
   * the referral and mints her welcome coupon — and that coupon's code is
   * returned instead. Anything else comes back unchanged, so the coupon rail
   * raises the refusal and she is told the code is invalid exactly once, in
   * the usual words.
   *
   * Applying the invite here rather than making her do it on another screen is
   * the point: «استخدمت الكود بأول عملية شراء» is one action from her side and
   * used to be two, one of which was invisible and paid nothing she could see.
   */
  private async resolveCouponCode(
    typed: string,
    userId: string,
  ): Promise<string> {
    const code = typed.trim();
    const asCoupon = await this.prisma.coupon.findUnique({
      where: { code: code.toUpperCase() },
      select: { id: true },
    });
    if (asCoupon) return code;

    const invite = await this.referrals.findLiveCode(code);
    if (!invite) return code;

    try {
      const applied = await this.referrals.applyCode(userId, { code });
      const welcome = applied.welcome_coupon?.code;
      if (welcome) return welcome;
    } catch (error) {
      // A refused invite — her own code, an account that already used one,
      // a fraud score over the line — is not a reason to fail the checkout.
      // She is told her *code* did not apply, by the coupon rail, a line
      // below.
      this.logger.warn(`Referral code not applied at checkout: ${String(error)}`);
    }
    return code;
  }

  /**
   * `number` is unique, so a collision fails the whole checkout. The suffix
   * comes from the OS CSPRNG with ~1.7M values per millisecond (it was 900
   * from `Math.random()`), which also keeps the next number unguessable.
   */
  private orderNumber(): string {
    const stamp = Date.now().toString(36).toUpperCase();
    const noise = randomInt(36 ** 3, 36 ** 4).toString(36).toUpperCase();
    return `REEM-${stamp}${noise}`;
  }
}

/** Re-exported for the settlement job that releases escrow. */
export const ESCROW_WINDOW_DAYS = RETURN_WINDOW_DAYS;

export type CheckoutTransaction = Prisma.TransactionClient;
