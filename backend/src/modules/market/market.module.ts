import { Module } from '@nestjs/common';
import { GraphModule } from '../graph/graph.module';
import { BundlesService } from './bundles/bundles.service';
import { DropsService } from './drops/drops.service';
import { MarketEconomicsService } from './economics/market-economics.service';
import { MarketIntelligenceService } from './intelligence/market-intelligence.service';
import { MissionsService } from './missions/missions.service';
import { LifecycleService } from './resale/lifecycle.service';
import { MarketAdminController } from './market.admin.controller';
import { MarketController } from './market.controller';
import { MarketScheduler } from './market.scheduler';
import { MarketSellerController } from './market.seller.controller';

/**
 * Reem Market Evolution.
 *
 * Six systems over one reading. `MarketEconomicsService` computes supply
 * against demand for every category and live product; everything else consumes
 * that reading rather than gathering facts of its own — drops pick what to
 * launch from it, market intelligence turns it into sentences, and the seller
 * and admin screens read the same numbers so they cannot disagree.
 *
 * The two systems that do not read economics read the graph instead: bundles
 * are assembled from its complement relations, and drops choose their audience
 * from its per-shopper edges. Neither computes a similarity or an affinity of
 * its own, which is the rule that keeps this phase from becoming a second
 * opinion about the same catalogue.
 *
 * The life cycle reads the closet, and missions read whatever tables the thing
 * they ask for lives in. Neither invents a new fact table, and missions in
 * particular mint nothing at all — see the kernel.
 *
 * No LLM anywhere. Every sentence on every one of these screens is written
 * beside the arithmetic that produced it, in `market.serializer.ts` and the
 * intelligence layer's `phrase()`. A model could phrase them more warmly
 * later; nothing here waits on one to decide what is true.
 */
@Module({
  imports: [GraphModule],
  controllers: [MarketController, MarketSellerController, MarketAdminController],
  providers: [
    MarketEconomicsService,
    MarketIntelligenceService,
    DropsService,
    BundlesService,
    LifecycleService,
    MissionsService,
    MarketScheduler,
  ],
  // Drops so the order pipeline can record a conversion; economics because a
  // seller's own screens read the same market reading the admin's do.
  exports: [DropsService, MarketEconomicsService, MarketIntelligenceService],
})
export class MarketModule {}
