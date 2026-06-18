import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  DeliveryStatus,
  OrderStatus,
  Payment,
  PaymentMethodType,
  PaymentStatus,
} from '@prisma/client';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../../prisma/prisma.service';
import { serializePayment } from '../../common/serializers';
import { AppEvent } from '../../common/events/app-events';
import { CommissionsService } from '../commissions/commissions.service';
import { PaymentProviderRegistry } from './providers/payment-provider.registry';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly registry: PaymentProviderRegistry,
    private readonly events: EventEmitter2,
    private readonly commissions: CommissionsService,
  ) {}

  methods() {
    return this.registry.list();
  }

  /** Creates the payment for a freshly-placed order and starts the provider flow. */
  async initiateForOrder(
    orderId: string,
    orderNumber: string,
    amount: number,
    method: PaymentMethodType,
  ): Promise<{
    payment: Payment;
    redirectUrl: string | null;
    requiresOnlineConfirmation: boolean;
  }> {
    const provider = this.registry.get(method);
    const result = await provider.initiate({ amount, orderNumber });

    const payment = await this.prisma.payment.create({
      data: {
        orderId,
        method,
        amount,
        status: result.status,
        transactionRef: result.transactionRef,
        providerRef: result.providerRef ?? null,
        transactions: {
          create: [
            {
              event: 'initiated',
              status: result.status,
              amount,
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

  /** Confirms a pending online payment (simulated gateway callback). */
  async verify(userId: string, paymentId: string) {
    const payment = await this.requireOwned(userId, paymentId);
    if (payment.status === PaymentStatus.PAID) {
      return serializePayment(payment);
    }

    const provider = this.registry.get(payment.method);
    const result = await provider.verify(payment.transactionRef ?? '');

    const updated = await this.prisma.$transaction(async (tx) => {
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
          amount: payment.amount,
          message: result.message ?? null,
        },
      });
      if (result.status === PaymentStatus.PAID) {
        await tx.order.update({
          where: { id: payment.orderId },
          data: {
            status: OrderStatus.PAID,
            deliveryStatus: DeliveryStatus.CONFIRMED,
          },
        });
        await tx.orderEvent.create({
          data: {
            orderId: payment.orderId,
            title: 'Payment received',
            description: `${provider.displayName} payment confirmed`,
          },
        });
      }
      return p;
    });

    if (result.status === PaymentStatus.PAID) {
      await this.commissions.settleOrder(payment.orderId);
      const order = await this.prisma.order.findUnique({
        where: { id: payment.orderId },
        select: { userId: true, number: true },
      });
      if (order) {
        this.events.emit(AppEvent.OrderStatusChanged, {
          userId: order.userId,
          orderId: payment.orderId,
          orderNumber: order.number,
          status: 'paid',
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

    const provider = this.registry.get(payment.method);
    const order = await this.prisma.order.findUnique({
      where: { id: payment.orderId },
      select: { number: true },
    });
    const result = await provider.initiate({
      amount: payment.amount,
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

  private async requireOwned(userId: string, paymentId: string): Promise<Payment> {
    const payment = await this.prisma.payment.findFirst({
      where: { id: paymentId, order: { userId } },
    });
    if (!payment) throw new NotFoundException('Payment not found');
    return payment;
  }
}
