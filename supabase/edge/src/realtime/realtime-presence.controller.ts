import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { PresenceStatus } from '@prisma/client';
import { Transform } from 'class-transformer';
import { IsEnum } from 'class-validator';
import { CurrentUser } from '../../../../backend/src/common/decorators/current-user.decorator';
import { SelfScoped } from '../../../../backend/src/common/decorators/self-scoped.decorator';
import { ChatsService } from '../../../../backend/src/modules/chats/chats.service';

export class PresenceDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.toUpperCase() : value))
  @IsEnum(PresenceStatus)
  status!: PresenceStatus;
}

/**
 * Presence, which the WebSocket gateway inferred from open sockets.
 *
 * With no socket in this process to count, the app says so itself: `online`
 * when its Realtime channel joins and on a slow heartbeat, `offline` when it
 * leaves. The backend's `setPresence` stores it and emits the same
 * `chat.presence.changed` event, which `SupabaseRealtimeGateway` fans out.
 */
@SelfScoped('sets only the caller\'s own presence, from her access token')
@Controller('realtime')
export class RealtimePresenceController {
  constructor(private readonly chats: ChatsService) {}

  @Throttle({ default: { limit: 12, ttl: 60_000 } })
  @Post('presence')
  @HttpCode(HttpStatus.OK)
  async presence(@CurrentUser('id') userId: string, @Body() dto: PresenceDto) {
    const presence = await this.chats.setPresence(
      userId,
      dto.status,
      dto.status === PresenceStatus.OFFLINE ? 0 : 1,
    );
    return {
      status: presence.status.toLowerCase(),
      last_seen_at: presence.lastSeenAt.toISOString(),
    };
  }
}
