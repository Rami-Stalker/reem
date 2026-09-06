import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { CodAssuranceState, OrderStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { OrdersService } from '../orders/orders.service';

/**
 * Lets go of orders nobody came back to confirm.
 *
 * Holding a cash order for a code is only defensible if the hold ends. Its
 * stock came off the seller's offer the moment it was placed, so an order that
 * waits forever is a dress nobody can buy for a customer who has already
 * stopped shopping — and the seller never even hears about it.
 *
 * Every ten minutes rather than nightly: the window is thirty minutes, and a
 * sweep coarser than the window it enforces would hold an abandoned order for
 * hours past its own deadline — the stock stays off the shelf that whole time,
 * and the seller never hears why.
 *
 * Cancellation runs through `OrdersService.cancel` rather than a status write
 * here, so the stock goes back through the one path that knows how, the
 * timeline records it, and she is told the same way she is told about any
 * other cancellation.
 *
 * **Registered by `OrdersModule`, not by `CodTrustModule`.** The trust engine
 * must not depend on orders — orders already depends on it, and closing that
 * loop would put a `forwardRef` between two modules with no reason to know
 * each other in both directions. The file lives beside the rest of the engine
 * because that is where a reader will look for it.
 */
@Injectable()
export class CodTrustScheduler {
  private readonly logger = new Logger(CodTrustScheduler.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly orders: OrdersService,
  ) {}

  @Cron(CronExpression.EVERY_10_MINUTES)
  async releaseExpiredHolds(): Promise<void> {
    const expired = await this.prisma.codRiskAssessment.findMany({
      where: {
        state: CodAssuranceState.PENDING,
        expiresAt: { lt: new Date() },
        order: { status: OrderStatus.PENDING_PAYMENT },
      },
      select: { id: true, orderId: true, userId: true },
      take: 200,
    });

    let released = 0;
    for (const assessment of expired) {
      try {
        await this.prisma.codRiskAssessment.update({
          where: { id: assessment.id },
          data: { state: CodAssuranceState.ABANDONED },
        });
        if (assessment.userId) {
          await this.orders.cancel(
            assessment.userId,
            assessment.orderId,
            'انتهت مهلة تأكيد الطلب',
          );
        }
        released += 1;
      } catch (error) {
        // One order that will not cancel — a parcel a seller already moved,
        // most likely — must not stop the rest of the sweep.
        this.logger.warn(
          `Could not release the expired hold on ${assessment.orderId}: ${
            (error as Error).message
          }`,
        );
      }
    }

    if (released) {
      this.logger.log(`Released ${released} expired cash-order holds`);
    }
  }
}
