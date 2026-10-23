import { Injectable, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import {
  AppEvent,
  OrderPlacedPayload,
} from '../../common/events/app-events';
import { AnalyticsService } from './analytics.service';

/**
 * Writes the funnel's last step when checkout commits an order.
 *
 * Asynchronous and failure-swallowing: a measurement must never cost a woman
 * her order, and the order is already committed by the time this runs.
 */
@Injectable()
export class OrderPlacedListener {
  private readonly logger = new Logger(OrderPlacedListener.name);

  constructor(private readonly analytics: AnalyticsService) {}

  @OnEvent(AppEvent.OrderPlaced, { async: true })
  async handle(payload: OrderPlacedPayload): Promise<void> {
    try {
      await this.analytics.recordOrderPlaced(payload.orderId, payload.userId);
    } catch (error) {
      this.logger.warn(
        `ORDER_PLACED not recorded for ${payload.orderId}: ${String(error)}`,
      );
    }
  }
}
