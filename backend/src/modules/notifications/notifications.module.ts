import { Module } from '@nestjs/common';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { PushTransport } from './transports/push.transport';
import { NotificationsRepository } from './notifications.repository';
import { ContactPolicyService } from './contact-policy.service';

@Module({
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    PushTransport,
    NotificationsRepository,
    ContactPolicyService,
  ],
  exports: [NotificationsService, ContactPolicyService],
})
export class NotificationsModule {}
