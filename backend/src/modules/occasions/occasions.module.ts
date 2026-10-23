import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { OccasionsController } from './occasions.controller';
import { OccasionsScheduler } from './occasions.scheduler';
import { OccasionsService } from './occasions.service';

/**
 * «مناسباتي».
 *
 * She writes down a day — her cousin's wedding, Eid, a graduation — and Reem
 * helps her get ready for it: a countdown, a look from her closet, a salon
 * booked in time, the gift, and a warning when the people who will be there
 * have already seen the dress.
 *
 * ## What it reuses rather than rebuilds
 *
 * Nearly everything, and that is the design:
 *
 *  - **The look** is a `ClosetLook`. Its missing pieces are already closet
 *    gaps with shop suggestions behind them, so "the look is missing shoes"
 *    needs no second recommendation engine.
 *  - **The salon** is an `Appointment`, booked through the salon flow that
 *    exists. The occasion only points at it and reads its status.
 *  - **Notifications** go through `NotificationsService` with one new type and
 *    one new channel, so she can mute the countdown without muting her orders.
 *
 * ## What is genuinely new
 *
 * The calendar row, the countdown, and «ما لبستيه قدّامهم» — matching an
 * outfit against the other occasions she named the same people for. All three
 * are arithmetic in `occasion-plan.ts`.
 *
 * ## What is deliberately absent
 *
 * **Sharing.** An occasion names who she will see and what she will wear; it
 * has no public route and no shared view. **Shop suggestions in the
 * countdown.** A reminder about her own wedding is not an advertising slot;
 * the shop is reached through the look's gaps, when she asks.
 */
@Module({
  imports: [NotificationsModule],
  controllers: [OccasionsController],
  providers: [OccasionsService, OccasionsScheduler],
  exports: [OccasionsService],
})
export class OccasionsModule {}
