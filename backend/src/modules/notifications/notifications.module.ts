import { Module } from '@nestjs/common';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { PushTransport } from './transports/push.transport';
import { NotificationsRepository } from './notifications.repository';

@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService, PushTransport, NotificationsRepository],
  exports: [NotificationsService],
})
export class NotificationsModule {}
