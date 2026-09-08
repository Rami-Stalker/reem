import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { CustomerSegmentsService } from './customer-segments.service';
import { LifecycleAdminController } from './lifecycle.admin.controller';
import { ReengagementService } from './reengagement.service';

/**
 * The customer lifecycle, and the two campaigns that ride on it.
 *
 * Segmentation is exported because other modules want to ask it questions —
 * an offer that should only reach `loyal` customers, a seller dashboard that
 * wants to know how many of her buyers came back. Nothing is exported that
 * sends anything.
 */
@Module({
  imports: [NotificationsModule],
  controllers: [LifecycleAdminController],
  providers: [CustomerSegmentsService, ReengagementService],
  exports: [CustomerSegmentsService, ReengagementService],
})
export class LifecycleModule {}
