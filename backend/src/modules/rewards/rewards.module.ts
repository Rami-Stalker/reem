import { Module } from '@nestjs/common';

import { FinanceModule } from '../finance/finance.module';
import {
  CouponsController,
  ReferralsController,
  RewardsController,
} from './rewards.controller';
import { CouponsService } from './coupons.service';
import { MembershipService } from './membership.service';
import { PointsService } from './points.service';
import { PurchaseRewardsService } from './purchase-rewards.service';
import { ReferralsService } from './referrals.service';

@Module({
  imports: [FinanceModule],
  controllers: [CouponsController, RewardsController, ReferralsController],
  providers: [
    CouponsService,
    PointsService,
    ReferralsService,
    MembershipService,
    PurchaseRewardsService,
  ],
  exports: [
    CouponsService,
    PointsService,
    ReferralsService,
    MembershipService,
    PurchaseRewardsService,
  ],
})
export class RewardsModule {}
