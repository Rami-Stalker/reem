import { Module } from '@nestjs/common';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';

import configuration from './config/configuration';
import { validateEnv } from './config/env.validation';
import { PrismaModule } from './prisma/prisma.module';
import { CacheModule } from './common/cache/cache.module';

import { IdempotencyInterceptor } from './common/idempotency/idempotency.interceptor';
import { AdminAuditInterceptor } from './common/audit/admin-audit.interceptor';
import { IdempotencySweeper } from './common/idempotency/idempotency.sweeper';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { DeviceProofGuard } from './common/guards/device-proof.guard';
import { StepUpGuard } from './common/guards/step-up.guard';
import { AuthorizationGuard } from './common/authorization/authorization.guard';
import { AuthorizationService } from './common/authorization/authorization.service';

import { AuthModule } from './modules/auth/auth.module';
import { MediaModule } from './modules/media/media.module';
import { UsersModule } from './modules/users/users.module';
import { PricingModule } from './modules/pricing/pricing.module';
import { ProductsModule } from './modules/products/products.module';
import { CommerceContentModule } from './modules/commerce-content/commerce-content.module';
import { PostsModule } from './modules/posts/posts.module';
import { StoriesModule } from './modules/stories/stories.module';
import { DiscoveryModule } from './modules/discovery/discovery.module';
import { SearchModule } from './modules/search/search.module';
import { CartModule } from './modules/cart/cart.module';
import { DeliveryModule } from './modules/delivery/delivery.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { OrdersModule } from './modules/orders/orders.module';
import { CodTrustModule } from './modules/cod-trust/cod-trust.module';
import { FavoritesModule } from './modules/favorites/favorites.module';
import { ChatsModule } from './modules/chats/chats.module';
import { SettingsModule } from './modules/settings/settings.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { RewardsModule } from './modules/rewards/rewards.module';
import { AdminModule } from './modules/admin/admin.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
import { TrendsModule } from './modules/trends/trends.module';
import { TrustModule } from './modules/trust/trust.module';
import { LifecycleModule } from './modules/lifecycle/lifecycle.module';
import { PromotionsModule } from './modules/promotions/promotions.module';
import { ExperimentsModule } from './modules/experiments/experiments.module';
import { CustomerIntelligenceModule } from './modules/customer-intelligence/customer-intelligence.module';
import { RankingModule } from './modules/ranking/ranking.module';
import { AdminIntelligenceModule } from './modules/admin-intelligence/admin-intelligence.module';
import { SellerIntelligenceModule } from './modules/seller-intelligence/seller-intelligence.module';
import { GraphModule } from './modules/graph/graph.module';
import { IntelligenceModule } from './modules/intelligence/intelligence.module';
import { MarketModule } from './modules/market/market.module';
import { ReputationModule } from './modules/reputation/reputation.module';
import { AiAssistantModule } from './modules/ai-assistant/ai-assistant.module';
import { AiStylistModule } from './modules/ai-stylist/ai-stylist.module';
import { VisualSearchModule } from './modules/visual-search/visual-search.module';
import { ClosetModule } from './modules/closet/closet.module';
import { ValueModule } from './modules/value/value.module';
import { RoomsModule } from './modules/rooms/rooms.module';
import { CommissionsModule } from './modules/commissions/commissions.module';
import { LedgerModule } from './modules/ledger/ledger.module';
import { FinanceModule } from './modules/finance/finance.module';
import { ReturnsModule } from './modules/returns/returns.module';
import { SupportModule } from './modules/support/support.module';
import { SellerCommerceModule } from './modules/seller-commerce/seller-commerce.module';
import { ExperienceModule } from './modules/experience/experience.module';
import { HealthModule } from './modules/health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      validate: validateEnv,
    }),
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => [
        {
          ttl: (config.get<number>('rateLimit.ttl') ?? 60) * 1000,
          limit: config.get<number>('rateLimit.limit') ?? 120,
        },
      ],
    }),
    ScheduleModule.forRoot(),
    EventEmitterModule.forRoot(),
    PrismaModule,
    CacheModule,

    // Global: every write path that stores a URL claims its upload here.
    MediaModule,
    AuthModule,
    UsersModule,
    PricingModule,
    ProductsModule,
    CommerceContentModule,
    PostsModule,
    StoriesModule,
    DiscoveryModule,
    SearchModule,
    TrustModule,
    LifecycleModule,
    PromotionsModule,
    ExperimentsModule,
    CustomerIntelligenceModule,
    RankingModule,
    AdminIntelligenceModule,
    CartModule,
    DeliveryModule,
    PaymentsModule,
    CodTrustModule,
    OrdersModule,
    FavoritesModule,
    ChatsModule,
    SettingsModule,
    NotificationsModule,
    RewardsModule,
    AdminModule,
    AnalyticsModule,
    TrendsModule,
    // Phase two of the commerce OS. Reads the trend engine's tables, so it is
    // registered after it — Nest does not care about the order, but the next
    // person reading this list should see which way the dependency runs.
    SellerIntelligenceModule,
    // Phase three. The graph projects from everything above it; intelligence
    // reads the graph. Registered last because that is the direction the
    // dependency runs — nothing below knows either of them exists.
    GraphModule,
    IntelligenceModule,
    MarketModule,
    ReputationModule,
    AiAssistantModule,
    AiStylistModule,
    // After AiStylistModule, which it imports for the brief extractor.
    VisualSearchModule,
    // After AiStylistModule too: a wardrobe gap is answered by the stylist's
    // retrieval and ranker rather than by a second search of its own.
    ClosetModule,
    // Reem Value — standing, computed from evidence the other modules already
    // hold. It reads them; none of them knows it exists.
    ValueModule,
    // Reem Rooms — deliberation before purchase. After OrdersModule, whose
    // checkout it calls with its own lines rather than through a cart.
    RoomsModule,
    CommissionsModule,
    LedgerModule,
    FinanceModule,
    ReturnsModule,
    SupportModule,
    SellerCommerceModule,
    ExperienceModule,
    HealthModule,
  ],
  providers: [
    // Order matters: throttle → authenticate → authorize.
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    // After JwtAuth so a proof can be bound to the presented access token,
    // before AuthorizationGuard so a handler never runs on an unproven device.
    { provide: APP_GUARD, useClass: DeviceProofGuard },
    // After the proof guard, which is what populates `request.provenDevice`.
    { provide: APP_GUARD, useClass: StepUpGuard },
    AuthorizationService,
    { provide: APP_GUARD, useClass: AuthorizationGuard },
    // After the guards, so the principal is resolved before the key is scoped
    // to it — an interceptor registered here runs inside the guard chain, and
    // scoping an idempotency key to `ip:` when the caller is signed in would
    // let two accounts behind one NAT collide.
    { provide: APP_INTERCEPTOR, useClass: IdempotencyInterceptor },
    IdempotencySweeper,
    // Records every staff write, so coverage does not depend on each service
    // remembering to. Note what it cannot see: guards run *before*
    // interceptors, so a request `AuthorizationGuard` refuses never reaches
    // this — that denial is written to `SecurityEvent` by the guard itself.
    // What this catches is the refusal thrown *inside* a handler, which is
    // where most of this platform's ownership checks live.
    { provide: APP_INTERCEPTOR, useClass: AdminAuditInterceptor },
  ],
})
export class AppModule {}
