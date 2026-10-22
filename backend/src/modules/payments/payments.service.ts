import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  Optional,
  forwardRef,
} from '@nestjs/common';
import {
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  OrderStatus,
  Payment,
  PaymentMethodType,
  PaymentStatus,
  Prisma,
} from '@prisma/client';
import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../../prisma/prisma.service';
import { OrderEventCopy } from '../../common/orders/order-event-copy';
import { PaymentRail, railOf } from '../../common/payments/payment-rails';
import { serializePayment } from '../../common/serializers';
import { AppEvent } from '../../common/events/app-events';
import { Money } from '../../common/money';
import { CheckoutService } from '../orders/checkout.service';
import { LedgerService } from '../ledger/ledger.service';
import { WalletService } from '../ledger/wallet.service';
import { PaymentProviderRegistry } from './providers/payment-provider.registry';
import {
  FinancialAction,
  FinancialAuditService,
} from '../finance/financial-audit.service';

/**
 * How long finance has to match a transfer once she has sent its reference.
 *
 * The order's own 72-hour deadline (`order-expiry.ts`) is for a woman who has
 * not paid yet. Once she says she has, the money may already be on its way
 * and cancelling her order — putting the dress back on sale — because finance
 * had not got to the queue would be the platform's fault, not hers. So the
 * deadline restarts from her submission.
 */
export const TRANSFER_REVIEW_HOURS = 72;

const MANUAL_METHODS: readonly PaymentMethodType[] = Object.values(
  PaymentMethodType,
).filter((method) => railOf(method) === PaymentRail.MANUAL);

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly registry: PaymentProviderRegistry,
    private readonly events: EventEmitter2,
    @Inject(forwardRef(() => CheckoutService))
    private readonly checkout: CheckoutService,
    private readonly ledger: LedgerService,
    private readonly wallets: WalletService,
    private readonly config: ConfigService,
    @Optional()
    private readonly financialAudit?: FinancialAuditService,
  ) {}

  /** See `configuration.ts` — off everywhere but a developer's machine. */
  private get sandboxConfirmation(): boolean {
    return this.config.get<boolean>('payments.sandboxConfirmation') === true;
  }

  /**
   * The moment an electronic payment clears.
   *
   * The order's settlement books the gross against `GATEWAY_RECEIVABLE` — the
   * provider has the money, we do not yet. This is the other half: the funds
   * land in our account and the receivable is discharged. Without it the
   * receivable would grow forever and platform cash would understate what we
   * actually hold.
   *
   * Cash on delivery and wallet payments are skipped: neither passes through a
   * provider, and their cash movements are recorded by the courier settlement
   * (Q56) and the wallet spend respectively.
   */
  private async postCapture(
    tx: Prisma.TransactionClient,
    payment: Payment,
  ): Promise<void> {
    if (!this.clearsThroughGateway(payment.method)) return;

    const amount = Money.of(payment.amount, payment.currency);
    if (amount.isZero()) return;

    await this.ledger.post(
      {
        type: JournalEntryType.PAYMENT_CAPTURED,
        reference: `payment-captured:${payment.id}`,
        description: OrderEventCopy.paymentCleared(payment.method),
        orderId: payment.orderId,
        lines: [
          {
            account: { code: LedgerAccountCode.PLATFORM_CASH },
            direction: LedgerDirection.DEBIT,
            amount,
          },
          {
            account: { code: LedgerAccountCode.GATEWAY_RECEIVABLE },
            direction: LedgerDirection.CREDIT,
            amount,
            memo: 'Receivable discharged on clearing',
          },
        ],
        metadata: { payment_id: payment.id } as Prisma.InputJsonValue,
      },
      tx,
    );
  }

  /**
   * Debits the customer's wallet for an order.
   *
   * Idempotent through the movement's reference, so a retry of the same order
   * cannot spend twice; `WalletService.spend` takes the row lock and refuses an
   * overdraw, which is what makes the balance check meaningful under two
   * concurrent checkouts rather than merely reassuring.
   */
  private async spendWallet(
    orderId: string,
    orderNumber: string,
    amount: Money,
    userId?: string | null,
  ): Promise<void> {
    if (!userId) {
      // Q46 P1 lets guests buy, but a guest has no wallet to spend from.
      throw new BadRequestException(
        'Paying from the wallet requires a signed-in account',
      );
    }

    await this.wallets.spend({
      userId,
      amount,
      reason: `دفع الطلب ${orderNumber}`,
      orderId,
      reference: `order-payment:${orderId}`,
    });
  }

  /** The methods whose money sits with a provider before reaching us. */
  private clearsThroughGateway(method: PaymentMethodType): boolean {
    return (
      method === PaymentMethodType.SYRIATEL_CASH ||
      method === PaymentMethodType.MTN_CASH ||
      method === PaymentMethodType.SHAM_CASH ||
      method === PaymentMethodType.BANK_CARD ||
      method === PaymentMethodType.BANK_TRANSFER ||
      method === PaymentMethodType.HAWALA
    );
  }

  /**
   * The rails a customer can actually finish paying on, today.
   *
   * Every provider is listed in the registry, and the registry used to be
   * what checkout offered. But a rail is only a rail if the money can arrive:
   *
   * - an online gateway needs a provider that can attest the payment (none
   *   can yet — no merchant account exists), or the developer sandbox;
   * - a bank transfer or hawala needs instructions saying who to pay.
   *
   * Offered without those, she picked it, was sent to a page that did not
   * exist or told to transfer to nobody, and her order expired an hour or
   * three days later. Cash and the wallet always work.
   */
  methods() {
    return Object.values(PaymentMethodType)
      .filter((method) => this.isAvailable(method))
      .map((method) => {
        const provider = this.registry.get(method);
        return {
          method: method.toLowerCase(),
          label: provider.displayName,
          requires_online_confirmation: provider.requiresOnlineConfirmation,
          rail: railOf(method),
          instructions: this.instructionsFor(method),
        };
      });
  }

  /** Whether an order may be placed on this rail right now. */
  isAvailable(method: PaymentMethodType): boolean {
    switch (railOf(method)) {
      case PaymentRail.MANUAL:
        return this.instructionsFor(method) !== null;
      case PaymentRail.ONLINE:
        return (
          this.registry.get(method).attestsSettlement || this.sandboxConfirmation
        );
      default:
        return true;
    }
  }

  /** Refuses a rail the customer could not finish paying on. */
  assertAvailable(method: PaymentMethodType): void {
    if (!this.isAvailable(method)) {
      throw new BadRequestException({
        code: 'PAYMENT_METHOD_UNAVAILABLE',
        message: 'طريقة الدفع هذه غير متاحة حالياً — اختاري طريقة أخرى',
      });
    }
  }

  /** Who to pay, for a manual rail; null when finance has not set it. */
  instructionsFor(method: PaymentMethodType): string | null {
    const all = this.config.get<Partial<Record<PaymentMethodType, string | null>>>(
      'payments.manualInstructions',
    );
    return all?.[method] ?? null;
  }

  /** Creates the payment for a freshly-placed order and starts the provider flow. */
  async initiateForOrder(
    orderId: string,
    orderNumber: string,
    amount: Money,
    method: PaymentMethodType,
    userId?: string | null,
  ): Promise<{
    payment: Payment;
    redirectUrl: string | null;
    requiresOnlineConfirmation: boolean;
  }> {
    const provider = this.registry.get(method);

    // Paying from the wallet is the one method where the money moves *here*.
    // Every other rail is a promise about cash somewhere else — a courier's
    // pocket, a provider's account — that some later event confirms. The
    // wallet is ours, and its provider used to answer PAID without anyone
    // touching the balance, which meant a customer with an empty wallet could
    // check out for free. The debit happens before the payment row exists, so
    // an insufficient balance stops the order rather than recording a payment
    // that never happened.
    if (method === PaymentMethodType.PLATFORM_WALLET) {
      await this.spendWallet(orderId, orderNumber, amount, userId);
    }

    const result = await provider.initiate({
      amount: amount.toJSON().amount,
      currency: amount.currency,
      orderNumber,
    });

    const payment = await this.prisma.payment.create({
      data: {
        orderId,
        method,
        currency: amount.currency,
        amount: amount.toPrisma(),
        capturedAmount:
          result.status === PaymentStatus.PAID
            ? amount.toPrisma()
            : Money.zero(amount.currency).toPrisma(),
        status: result.status,
        transactionRef: result.transactionRef,
        providerRef: result.providerRef ?? null,
        transactions: {
          create: [
            {
              event: 'initiated',
              status: result.status,
              currency: amount.currency,
              amount: amount.toPrisma(),
              message: result.message ?? null,
            },
          ],
        },
      },
    });

    return {
      payment,
      redirectUrl: result.redirectUrl ?? null,
      requiresOnlineConfirmation: provider.requiresOnlineConfirmation,
    };
  }

  /**
   * Confirms a pending payment.
   *
   * This is reachable by the customer who owns the payment, and every provider
   * today is a stub whose `verify` returns PAID without asking anyone —
   * because no merchant account exists yet and cash settles elsewhere. Those
   * two facts together were a way to buy for free: confirm your own payment,
   * the ledger takes a `PLATFORM_CASH` debit, `checkout.confirm` fans the
   * sub-orders out and the sellers ship.
   *
   * So a rail may only settle here if its provider can genuinely attest that
   * money moved. None can, which is why the sandbox switch exists and why
   * `env.validation` refuses it in production. Nothing is lost by refusing:
   * cash and courier-collect reach PAID through
   * `SellerOrderWorkflowService.recordCollection`, on a real collection, with
   * `capturedAmount` tracked — the path that was always the honest one.
   */
  async verify(userId: string, paymentId: string) {
    const payment = await this.requireOwned(userId, paymentId);
    if (payment.status === PaymentStatus.PAID) {
      return serializePayment(payment);
    }
    // A transfer is confirmed by finance, never by asking. «تحقّقي مجدداً»
    // on one used to answer 403; the honest answer is where it stands.
    if (railOf(payment.method) === PaymentRail.MANUAL) {
      return serializePayment(payment);
    }

    const provider = this.registry.get(payment.method);
    if (!provider.attestsSettlement && !this.sandboxConfirmation) {
      throw new ForbiddenException('PAYMENT_CONFIRMATION_UNAVAILABLE');
    }
    if (payment.status === PaymentStatus.REFUNDED) {
      throw new BadRequestException('This payment has already been refunded');
    }
    await this.assertOrderAwaitsPayment(payment.orderId);
    const result = await provider.verify(payment.transactionRef ?? '');

    const updated = await this.prisma.$transaction(async (tx) => {
      // The status read above is a snapshot, and two confirmations of one
      // payment (a double tap, a retried request) both passed it. Claiming
      // the row on its *current* status lets exactly one of them through; the
      // other finds the payment already settled and reports it as it stands.
      const claimed = await tx.payment.updateMany({
        where: {
          id: paymentId,
          status: { in: [PaymentStatus.PENDING, PaymentStatus.FAILED] },
        },
        data: { updatedAt: new Date() },
      });
      if (claimed.count === 0) {
        return null;
      }

      const p = await tx.payment.update({
        where: { id: paymentId },
        data: {
          status: result.status,
          providerRef: result.providerRef ?? payment.providerRef,
          paidAt: result.status === PaymentStatus.PAID ? new Date() : null,
          failureReason:
            result.status === PaymentStatus.FAILED
              ? (result.message ?? 'Payment failed')
              : null,
        },
      });
      await tx.paymentTransaction.create({
        data: {
          paymentId,
          event: result.status === PaymentStatus.PAID ? 'succeeded' : 'failed',
          status: result.status,
          currency: payment.currency,
          amount: payment.amount,
          message: result.message ?? null,
        },
      });
      if (result.status === PaymentStatus.PAID) {
        await tx.payment.update({
          where: { id: paymentId },
          data: { capturedAmount: payment.amount },
        });
        await this.postCapture(tx, payment);
        await tx.orderEvent.create({
          data: {
            orderId: payment.orderId,
            title: OrderEventCopy.paymentReceived,
            description: OrderEventCopy.paymentConfirmed(provider.displayName),
            toStatus: OrderStatus.CONFIRMED,
            actorRole: 'SYSTEM',
          },
        });
        // In the same transaction as the payment. Confirmed separately, a
        // failure between the two left an order marked paid and still
        // pending — which the expiry sweep then cancelled, stock and all,
        // with her money taken.
        await this.checkout.confirm(payment.orderId, userId, tx);
      }
      return p;
    });

    if (!updated) {
      // Someone else settled it first; what they settled is the answer.
      return serializePayment(await this.requireOwned(userId, paymentId));
    }

    if (result.status === PaymentStatus.PAID) {
      const order = await this.prisma.order.findUnique({
        where: { id: payment.orderId },
        select: { userId: true, number: true },
      });
      if (order) {
        this.events.emit(AppEvent.OrderStatusChanged, {
          userId: order.userId,
          orderId: payment.orderId,
          orderNumber: order.number,
          status: OrderStatus.CONFIRMED,
        });
      }
    }

    return serializePayment(updated);
  }

  /** Failed-payment recovery: re-initiate the provider flow with a fresh ref. */
  async retry(userId: string, paymentId: string) {
    const payment = await this.requireOwned(userId, paymentId);
    if (
      payment.status !== PaymentStatus.FAILED &&
      payment.status !== PaymentStatus.PENDING
    ) {
      throw new BadRequestException('This payment can no longer be retried');
    }

    // A wallet payment is settled the instant it is made, by the debit in
    // `initiateForOrder`. Its provider answers PAID to any initiation, so
    // re-initiating one would mark it paid without touching the balance.
    if (payment.method === PaymentMethodType.PLATFORM_WALLET) {
      throw new BadRequestException(
        'A wallet payment cannot be retried — place the order again',
      );
    }
    await this.assertOrderAwaitsPayment(payment.orderId);

    const provider = this.registry.get(payment.method);
    const order = await this.prisma.order.findUnique({
      where: { id: payment.orderId },
      select: { number: true },
    });
    const result = await provider.initiate({
      amount: payment.amount.toFixed(4),
      currency: payment.currency,
      orderNumber: order?.number ?? '',
    });

    const updated = await this.prisma.payment.update({
      where: { id: paymentId },
      data: {
        status: result.status,
        transactionRef: result.transactionRef,
        failureReason: null,
        transactions: {
          create: [
            {
              event: 'initiated',
              status: result.status,
              currency: payment.currency,
              amount: payment.amount,
              message: result.message ?? 'Retry initiated',
            },
          ],
        },
      },
    });

    return {
      payment: serializePayment(updated),
      redirect_url: result.redirectUrl ?? null,
    };
  }

  /**
   * Q51 — «تحويل بنكي / حوالة»: she has sent the money and is telling us how
   * to find it.
   *
   * The manual rails have always instructed her to "submit your reference"
   * and the app had nowhere to submit it: her order sat PENDING with a button
   * that called `verify`, which for these rails answers "still waiting" by
   * design. The reference is recorded against the payment and on the order's
   * timeline, so finance can match it and she can see that it landed.
   *
   * The status deliberately does not move. Only an operator confirming the
   * transfer marks it paid — a customer typing a number is a claim, not a
   * receipt.
   */
  async submitReference(userId: string, paymentId: string, reference: string) {
    const payment = await this.requireOwned(userId, paymentId);

    if (railOf(payment.method) !== PaymentRail.MANUAL) {
      throw new BadRequestException(
        'This payment method does not take a transfer reference',
      );
    }
    if (payment.status !== PaymentStatus.PENDING) {
      throw new BadRequestException('This payment is already settled');
    }
    await this.assertOrderAwaitsPayment(payment.orderId);

    const trimmed = reference.trim();
    if (!trimmed) {
      throw new BadRequestException('Enter the transfer reference');
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      // She says she has paid: give finance its full window from now, for the
      // order and for the stock it is holding — see TRANSFER_REVIEW_HOURS.
      const deadline = new Date(
        Date.now() + TRANSFER_REVIEW_HOURS * 60 * 60 * 1000,
      );
      await tx.order.updateMany({
        where: {
          id: payment.orderId,
          OR: [{ expiresAt: null }, { expiresAt: { lt: deadline } }],
        },
        data: { expiresAt: deadline },
      });
      await tx.inventoryReservation.updateMany({
        where: {
          orderId: payment.orderId,
          expiresAt: { not: null, lt: deadline },
        },
        data: { expiresAt: deadline },
      });

      const row = await tx.payment.update({
        where: { id: paymentId },
        data: {
          providerRef: trimmed,
          failureReason: null,
          transactions: {
            create: [
              {
                event: 'reference_submitted',
                status: PaymentStatus.PENDING,
                currency: payment.currency,
                amount: payment.amount,
                message: `Customer reference: ${trimmed}`,
              },
            ],
          },
        },
      });

      await tx.orderEvent.create({
        data: {
          orderId: payment.orderId,
          title: 'أرسلت الزبونة رقم الحوالة',
          description: trimmed,
          actorRole: 'customer',
        },
      });

      return row;
    });

    return serializePayment(updated);
  }

  // ── Finance: matching transfers ───────────────────────────────────────

  /**
   * Q51 — the transfers waiting for someone in finance to match them.
   *
   * The other half of `submitReference`, which until now had none: a woman
   * could tell us her hawala number and nobody on the platform had a screen
   * to see it, a button to accept it, or a way to say it did not match.
   * Oldest deadline first, because that is the order they expire in.
   */
  async pendingTransfers() {
    const payments = await this.prisma.payment.findMany({
      where: {
        method: { in: [...MANUAL_METHODS] },
        status: PaymentStatus.PENDING,
        order: { status: OrderStatus.PENDING_PAYMENT },
      },
      include: {
        order: {
          select: {
            id: true,
            number: true,
            expiresAt: true,
            recipientName: true,
            recipientPhone: true,
          },
        },
        transactions: {
          where: { event: 'reference_submitted' },
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: { createdAt: true },
        },
      },
      orderBy: { createdAt: 'asc' },
      take: 200,
    });

    return payments
      .map((payment) => ({
        ...serializePayment(payment),
        order_number: payment.order.number,
        customer_name: payment.order.recipientName,
        customer_phone: payment.order.recipientPhone,
        expires_at: payment.order.expiresAt?.toISOString() ?? null,
        reference_submitted_at:
          payment.transactions[0]?.createdAt.toISOString() ?? null,
      }))
      .sort((a, b) =>
        (a.expires_at ?? '').localeCompare(b.expires_at ?? ''),
      );
  }

  /**
   * Finance found the transfer: the payment is settled and the order goes to
   * its sellers, in one transaction.
   *
   * Only for the manual rails — a gateway confirms itself, and cash is
   * settled by the courier who collected it. The order must still be waiting:
   * one that expired has already released its stock, and the transfer that
   * arrived for it is a refund to arrange by hand.
   */
  async confirmTransfer(actorId: string, paymentId: string, note?: string) {
    const payment = await this.requireTransfer(paymentId);
    if (payment.status === PaymentStatus.PAID) {
      return serializePayment(payment);
    }
    if (payment.status !== PaymentStatus.PENDING) {
      throw new BadRequestException('This payment is no longer pending');
    }
    await this.assertOrderAwaitsPayment(payment.orderId);
    const provider = this.registry.get(payment.method);

    const updated = await this.prisma.$transaction(async (tx) => {
      const claimed = await tx.payment.updateMany({
        where: { id: paymentId, status: PaymentStatus.PENDING },
        data: {
          status: PaymentStatus.PAID,
          paidAt: new Date(),
          capturedAmount: payment.amount,
          failureReason: null,
        },
      });
      if (claimed.count === 0) return null;

      await tx.paymentTransaction.create({
        data: {
          paymentId,
          event: 'confirmed_by_finance',
          status: PaymentStatus.PAID,
          currency: payment.currency,
          amount: payment.amount,
          message:
            note?.trim() ||
            `Transfer matched${payment.providerRef ? `: ${payment.providerRef}` : ''}`,
        },
      });
      await this.postCapture(tx, payment);
      await tx.orderEvent.create({
        data: {
          orderId: payment.orderId,
          title: 'Payment received',
          description: `${provider.displayName} — confirmed by finance`,
          toStatus: OrderStatus.CONFIRMED,
          actorId,
          actorRole: 'ADMIN',
        },
      });
      await this.checkout.confirm(payment.orderId, actorId, tx);
      return tx.payment.findUniqueOrThrow({ where: { id: paymentId } });
    });

    if (!updated) {
      return serializePayment(
        await this.prisma.payment.findUniqueOrThrow({ where: { id: paymentId } }),
      );
    }

    const order = await this.prisma.order.findUnique({
      where: { id: payment.orderId },
      select: { userId: true, number: true },
    });
    if (order) {
      this.events.emit(AppEvent.OrderStatusChanged, {
        userId: order.userId,
        orderId: payment.orderId,
        orderNumber: order.number,
        status: OrderStatus.CONFIRMED,
      });
    }

    await this.financialAudit?.record({
      action: FinancialAction.TransferConfirmed,
      actorId,
      subjectId: paymentId,
      subjectType: 'payment',
      before: PaymentStatus.PENDING,
      after: Money.of(payment.amount, payment.currency),
      reason: note ?? null,
      extra: {
        order_id: payment.orderId,
        method: payment.method,
        reference: payment.providerRef,
      },
    });

    return serializePayment(updated);
  }

  /**
   * Finance could not match the reference. The payment stays open and the
   * reference is cleared, so she can send the right one; the reason goes on
   * her timeline so she knows why.
   */
  async rejectTransfer(actorId: string, paymentId: string, reason: string) {
    const payment = await this.requireTransfer(paymentId);
    if (payment.status !== PaymentStatus.PENDING) {
      throw new BadRequestException('This payment is no longer pending');
    }
    const trimmed = reason.trim();
    if (!trimmed) throw new BadRequestException('Give the customer a reason');

    const updated = await this.prisma.$transaction(async (tx) => {
      const row = await tx.payment.update({
        where: { id: paymentId },
        data: {
          providerRef: null,
          failureReason: trimmed,
          transactions: {
            create: [
              {
                event: 'reference_rejected',
                status: PaymentStatus.PENDING,
                currency: payment.currency,
                amount: payment.amount,
                message: `${payment.providerRef ?? '—'}: ${trimmed}`,
              },
            ],
          },
        },
      });
      await tx.orderEvent.create({
        data: {
          orderId: payment.orderId,
          title: 'لم نتمكّن من مطابقة الحوالة',
          description: trimmed,
          actorId,
          actorRole: 'ADMIN',
        },
      });
      return row;
    });

    await this.financialAudit?.record({
      action: FinancialAction.TransferRejected,
      actorId,
      subjectId: paymentId,
      subjectType: 'payment',
      reason: trimmed,
      extra: { order_id: payment.orderId, reference: payment.providerRef },
    });

    return serializePayment(updated);
  }

  private async requireTransfer(paymentId: string): Promise<Payment> {
    const payment = await this.prisma.payment.findUnique({
      where: { id: paymentId },
    });
    if (!payment) throw new NotFoundException('Payment not found');
    if (railOf(payment.method) !== PaymentRail.MANUAL) {
      throw new BadRequestException(
        'Only bank transfers and hawala are confirmed by finance',
      );
    }
    return payment;
  }

  async history(userId: string) {
    const payments = await this.prisma.payment.findMany({
      where: { order: { userId } },
      orderBy: { createdAt: 'desc' },
    });
    return payments.map(serializePayment);
  }

  async detail(userId: string, paymentId: string) {
    return serializePayment(await this.requireOwned(userId, paymentId));
  }

  /**
   * Money may only be taken for an order that is still waiting for it.
   *
   * An order that expired unpaid has already put its stock back on the shelf
   * and released its hold; one a customer cancelled is owed nothing. Settling
   * a payment against either would charge her for goods that are no longer
   * hers, and confirm an order whose parcels have been called off.
   */
  private async assertOrderAwaitsPayment(orderId: string): Promise<void> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: { status: true },
    });
    if (!order || order.status !== OrderStatus.PENDING_PAYMENT) {
      throw new BadRequestException({
        code: 'ORDER_NOT_AWAITING_PAYMENT',
        message: 'This order is no longer waiting for payment',
      });
    }
  }

  private async requireOwned(userId: string, paymentId: string): Promise<Payment> {
    const payment = await this.prisma.payment.findFirst({
      where: { id: paymentId, order: { userId } },
    });
    if (!payment) throw new NotFoundException('Payment not found');
    return payment;
  }
}
