import { Injectable, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { OrderStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AppEvent, OrderStatusChangedPayload } from '../../common/events/app-events';
import { ClosetService } from './closet.service';
import { ClosetGapService } from './gaps/closet-gap.service';
import { ClosetItemService } from './items/closet-item.service';

/**
 * The closet fills itself.
 *
 * This is the mechanism by which a shop becomes a wardrobe. Left to manual
 * entry, a closet holds whatever a woman had the patience to type on the day she
 * discovered the feature — which is to say, almost nothing, and the gap engine
 * reasoning over almost nothing produces advice that is worse than none.
 * Delivery is the one moment Reem knows for certain she owns a garment, so that
 * is where the wardrobe grows.
 *
 * Three things keep it honest:
 *
 *   - It runs on DELIVERED, not on payment. An order that never arrives is not
 *     a garment she owns.
 *   - `closets.auto_add_purchases` turns it off, and it is a real switch: a
 *     woman who does not want her purchases logged is not one to be persuaded.
 *   - `closet_items.order_item_id` is unique, so a replayed event adds nothing.
 *     Event handlers get called twice; this one is built for it.
 *
 * Failures are logged and swallowed. Filling a closet is a courtesy attached to
 * a delivery, and a courtesy must never be able to fail the thing it is attached
 * to.
 */
@Injectable()
export class ClosetIntakeService {
  private readonly logger = new Logger(ClosetIntakeService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly closet: ClosetService,
    private readonly items: ClosetItemService,
    private readonly gaps: ClosetGapService,
  ) {}

  @OnEvent(AppEvent.OrderStatusChanged)
  async onOrderStatus(payload: OrderStatusChangedPayload): Promise<void> {
    if (payload.status !== OrderStatus.DELIVERED) return;
    try {
      await this.ingestOrder(payload.userId, payload.orderId);
    } catch (error) {
      this.logger.warn(
        `Closet intake failed for order ${payload.orderId}: ${String(error)}`,
      );
    }
  }

  /**
   * Add every delivered line of an order.
   *
   * Also exposed directly so a woman who turned the setting on after the fact —
   * or who opened the closet for the first time with a year of orders behind her
   * — can pull her history in. An empty closet is the feature's only real
   * failure mode, and this is the cheapest way out of it.
   */
  async ingestOrder(userId: string, orderId: string): Promise<number> {
    const closet = await this.closet.findOrCreate(userId);
    if (!closet.autoAddPurchases) return 0;

    const lines = await this.prisma.orderItem.findMany({
      where: {
        sellerOrder: { order: { id: orderId, userId } },
        productId: { not: null },
        // The line must not already be in the closet. The unique index would
        // catch it anyway; skipping early keeps the common replay free.
        closetItems: { none: {} },
      },
      select: { id: true },
    });

    let added = 0;
    for (const line of lines) {
      const item = await this.items.addFromOrderItem(userId, line.id);
      if (item) {
        added += 1;
        // A delivered purchase can close a gap the engine raised weeks ago, and
        // she should see that it did.
        await this.gaps.markFilledBy(item);
      }
    }

    if (added) await this.gaps.recompute(userId);
    return added;
  }

  /**
   * Backfill from her delivered order history.
   *
   * Bounded and newest-first: the point is a closet with enough in it to reason
   * over, not a complete archive of everything she has ever bought.
   */
  async backfill(userId: string, limit = 40): Promise<number> {
    const orders = await this.prisma.order.findMany({
      where: { userId, status: { in: [OrderStatus.DELIVERED, OrderStatus.CLOSED] } },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: { id: true },
    });

    let added = 0;
    for (const order of orders) added += await this.ingestOrder(userId, order.id);
    return added;
  }
}
