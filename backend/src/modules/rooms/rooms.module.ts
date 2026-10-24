import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { OrdersModule } from '../orders/orders.module';
import { PricingModule } from '../pricing/pricing.module';
import { PurchasePlanService } from './purchase-plan.service';
import { RoomAccessService } from './room-access.service';
import { RoomCollaborationService } from './room-collaboration.service';
import { RoomCompareService } from './room-compare.service';
import { RoomDecisionService } from './room-decision.service';
import { RoomEventService } from './room-event.service';
import { RoomNotifier } from './room-notifier.service';
import { RoomsController } from './rooms.controller';
import { RoomsService } from './rooms.service';

/**
 * Ohara Rooms.
 *
 * Intent → Room → Decision → Purchase, replacing Product → Cart → Checkout as
 * the path a considered purchase takes.
 *
 * ── What it replaces, and what it deliberately does not ──────────────────
 *
 * It replaces the *deliberation* half of buying: the flat basket where
 * proposing something and deciding to buy it are the same gesture. A room keeps
 * them apart — `addCandidate` proposes, `choose` decides — which is the whole
 * reason a cart fills up with things nobody ever decided on.
 *
 * It does **not** replace `CheckoutService`. That is 800 lines of frozen FX
 * rates, per-seller sub-orders, cash-on-delivery risk, escrow and commission,
 * and none of it is about deliberation. A plan reaches it through
 * `checkoutLines` with its own lines, so the two paths share one till and
 * `CartItem` is not a hidden staging buffer a room secretly fills.
 *
 * `CartModule` is also still here and still works. A room is for a purchase
 * worth thinking about; a woman replacing a bottle of shampoo should not have to
 * open one, and forcing every purchase through a deliberation surface would be
 * the same mistake as forcing every purchase through a flat list.
 *
 * ── Where the next features attach ───────────────────────────────────────
 *
 * All of them are new writers into tables that exist:
 *
 *  - **Candidates from the stylist.** `RoomDecision.slot` is an `OutfitSlot`, so
 *    a decision can already be handed to `ProductRetrievalService` as a brief —
 *    the same bridge `briefFromGap` uses in the closet.
 *  - **Candidates from her closet.** A room for an occasion and a closet gap for
 *    the same occasion are the same question asked twice; `ClosetGap.slot`
 *    matches `RoomDecision.slot`.
 *  - **Live collaboration.** `RoomEvent` is already an append-only stream keyed
 *    by room; the chat gateway's pattern would carry it.
 *  - **Ohara Value.** A room that reached PURCHASED is evidence of a considered
 *    purchase; a seventh pillar would read `PurchasePlan` rows.
 */
@Module({
  imports: [
    // For `CheckoutService.checkoutLines` — the one call a plan makes into the
    // order pipeline. The dependency runs one way: orders knows nothing about
    // rooms.
    OrdersModule,
    // For SYP normalisation, so a room's budget and a basket of dollar-priced
    // offers compare without a rate lookup at every comparison.
    PricingModule,
    // So a room notice reaches the phone of somebody who is not in the app.
    // `RoomNotifier` keeps writing its own rows — the coalescing rule is
    // rooms' knowledge, not notifications' — and only asks to have them sent.
    NotificationsModule,
  ],
  controllers: [RoomsController],
  providers: [
    RoomsService,
    RoomAccessService,
    RoomDecisionService,
    RoomCollaborationService,
    RoomCompareService,
    RoomEventService,
    RoomNotifier,
    PurchasePlanService,
  ],
  // `RoomAccessService` is exported for the surfaces that offer "add to a room"
  // from outside — the product page, the closet, the stylist. They ask whether
  // she may propose into a room and never learn what a decision is.
  exports: [RoomsService, RoomAccessService, PurchasePlanService],
})
export class RoomsModule {}
