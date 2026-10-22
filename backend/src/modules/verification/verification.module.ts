import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { MediaModule } from '../media/media.module';
import { NotificationsModule } from '../notifications/notifications.module';
import {
  AccountVerificationController,
  AdminAccountVerificationController,
} from './account-verification.controller';
import { AccountVerificationService } from './account-verification.service';

/// «توثيق الحساب». Deliberately separate from `SellerVerification`, which is
/// the permission to trade: a boutique can be allowed to sell without its
/// public identity being vouched for, and the two are judged against different
/// evidence by different people.
@Module({
  imports: [AuthModule, MediaModule, NotificationsModule],
  controllers: [AccountVerificationController, AdminAccountVerificationController],
  providers: [AccountVerificationService],
  exports: [AccountVerificationService],
})
export class VerificationModule {}
