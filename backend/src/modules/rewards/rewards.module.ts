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
import { ReferralsService } from './referrals.service';

@Module({
  imports: [FinanceModule],
  controllers: [CouponsController, RewardsController, ReferralsController],
  providers: [
    CouponsService,
    PointsService,
    ReferralsService,
    MembershipService,
  ],
  exports: [
    CouponsService,
    PointsService,
    ReferralsService,
    MembershipService,
  ],
})
export class RewardsModule {}
