import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { NotificationsModule } from '../notifications/notifications.module';
import { ChatRealtimeGateway } from './chat-realtime.gateway';
import { ChatsController } from './chats.controller';
import { ChatsService } from './chats.service';

@Module({
  imports: [JwtModule.register({}), NotificationsModule],
  controllers: [ChatsController],
  providers: [ChatsService, ChatRealtimeGateway],
  exports: [ChatsService],
})
export class ChatsModule {}
