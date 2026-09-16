import { Module } from '@nestjs/common';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { PushTransport } from './transports/push.transport';
import { FcmTransport } from './transports/fcm.transport';
import { WebhookPushTransport } from './transports/webhook-push.transport';
import { NotificationsRepository } from './notifications.repository';
import { ContactPolicyService } from './contact-policy.service';

@Module({
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    // The façade the service talks to, and the two backends under it. Which
    // one answers is decided by configuration at boot — see `PushTransport`.
    PushTransport,
    FcmTransport,
    WebhookPushTransport,
    NotificationsRepository,
    ContactPolicyService,
  ],
  exports: [NotificationsService, ContactPolicyService],
})
export class NotificationsModule {}
