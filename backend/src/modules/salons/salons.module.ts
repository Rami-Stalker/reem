import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { PricingModule } from '../pricing/pricing.module';
import { AppointmentsService } from './appointments.service';
import { SalonAvailabilityService } from './salon-availability.service';
import {
  AppointmentsController,
  SalonsController,
} from './salons.controller';
import { SalonsScheduler } from './salons.scheduler';
import { SalonsService } from './salons.service';

/**
 * «الصالونات والجمال».
 *
 * A woman finds a salon, sees what it does and what it charges, picks a day
 * and an hour, and books. The salon confirms, serves her, and is reviewed.
 *
 * ## What it reuses rather than rebuilds
 *
 * Almost everything, and that is the design:
 *
 *  - **Accounts and roles.** A salon is owned by a `SELLER` — the same vetted
 *    account a boutique belongs to. No new `UserRole`, because the role enum
 *    is read by every guard, the permission matrix, the admin console and the
 *    client's navigation map, and adding to it would touch all four to say
 *    something SELLER already says.
 *  - **Chat.** A customer messages a salon by messaging its owner, through
 *    `StartConversationDto.participant_id`, which already exists. There is no
 *    salon inbox and no second messaging system.
 *  - **Notifications.** One new `NotificationType` and one new push channel;
 *    the queue, the frequency policy, the delivery table, the retries and the
 *    deep-link routing are the ones that were already there.
 *  - **Addresses.** A home appointment points at a row in her existing address
 *    book. She types her address once, for parcels and for hands.
 *  - **Money.** `ExchangeRateService` normalises a menu to SYP exactly as it
 *    normalises a boutique's offers, so one directory can sort a mixed-currency
 *    price list.
 *  - **Media.** Service photographs and salon covers are ordinary uploads
 *    through `MediaModule`.
 *
 * ## What is genuinely new
 *
 * A calendar, and the rule that a slot cannot be sold twice. That rule lives
 * in `AppointmentsService.book` under a `FOR UPDATE` lock on the salon row,
 * and `SalonAvailabilityService` is the single answer to "when is this salon
 * free" that both the day picker and the booking ask — so a time she is
 * offered is a time she can take.
 *
 * ## What is deliberately absent
 *
 * **Money movement.** An appointment is a reservation, paid at the chair:
 * there is no ledger entry, no escrow, no commission and no order row. Adding
 * a payment rail here would put the salon's takings inside a double-entry
 * kernel that was written for parcels, and the client asked for booking rather
 * than for a till.
 *
 * **Staff.** A salon's capacity is a number (`concurrentCapacity`) rather than
 * a roster. Three chairs is the fact that makes the booking rule correct; who
 * is sitting in which one is a second feature, and the overlap check is
 * already written against a count so it will not need rewriting to gain one.
 */
@Module({
  imports: [
    // For `ExchangeRateService.toSyp`, so a salon's menu and a boutique's
    // offers are normalised at one rate.
    PricingModule,
    // So a confirmation reaches the phone of somebody who is not in the app.
    NotificationsModule,
  ],
  controllers: [SalonsController, AppointmentsController],
  providers: [
    SalonsService,
    SalonAvailabilityService,
    AppointmentsService,
    SalonsScheduler,
  ],
  exports: [SalonsService, AppointmentsService, SalonAvailabilityService],
})
export class SalonsModule {}
