import { Global, Module } from '@nestjs/common';
import { DiscoveryModule } from '@nestjs/core';
import { AuthModule } from '../../../backend/src/modules/auth/auth.module';
import { ChatsModule } from '../../../backend/src/modules/chats/chats.module';
import { IdentityLinkRepository } from './identity/identity-link.repository';
import { SendSmsHookService } from './identity/send-sms-hook.service';
import { SupabaseAuthClient } from './identity/supabase-auth.client';
import { SupabaseIdentityController } from './identity/supabase-identity.controller';
import { RealtimePresenceController } from './realtime/realtime-presence.controller';
import { CronRegistry } from './scheduling/cron-registry.service';
import { InternalCronController } from './scheduling/internal-cron.controller';
import { SupabaseHttp } from './supabase/supabase-http';

/**
 * Everything the Reem API needs to run on Supabase that the backend does not
 * already have — and nothing more.
 *
 * Global, because the classes that replace backend providers (the storage
 * driver in `MediaModule`, the Realtime gateway in `ChatsModule`) are
 * instantiated inside those modules and need `SupabaseHttp` there.
 */
@Global()
@Module({
  imports: [DiscoveryModule, AuthModule, ChatsModule],
  controllers: [SupabaseIdentityController, RealtimePresenceController, InternalCronController],
  providers: [SupabaseHttp, SupabaseAuthClient, IdentityLinkRepository, SendSmsHookService, CronRegistry],
  exports: [SupabaseHttp],
})
export class SupabaseBridgeModule {}
