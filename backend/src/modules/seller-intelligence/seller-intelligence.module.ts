import { Module } from '@nestjs/common';
import { DemandRadarService } from './radar/demand-radar.service';
import { ProductHealthService } from './product-health/product-health.service';
import { SellerHealthService } from './health/seller-health.service';
import { SellerIntelligenceController } from './seller-intelligence.controller';
import { SellerAdvisorService } from './advisor/seller-advisor.service';
import { SellerIntelligenceScheduler } from './seller-intelligence.scheduler';

/**
 * Reem Seller Intelligence — phase two of the commerce OS.
 *
 * Three systems that turn the seller console from a set of tables into
 * something that tells her what to do next:
 *
 *   `radar/`          what the market is asking for, read for her shop.
 *   `product-health/` which of her listings can meet it, and what to fix.
 *   `health/`         whether her shop can be trusted to deliver it.
 *
 * ── What it deliberately does not import ────────────────────────────────
 *
 * `TrendsModule`. The radar reads `CategoryDemandDaily`, `ProductDemandDaily`
 * and `UnmetDemandSignal` through Prisma directly rather than calling the
 * trend engine's services, and that is a deliberate choice rather than an
 * oversight: those tables are the contract, and taking a dependency on the
 * engine's *services* would couple a seller-facing screen to the internals of
 * a nightly pipeline. Reading the same rows keeps the numbers identical
 * without making either module hostage to the other's refactors.
 *
 * ── The one internal dependency worth naming ────────────────────────────
 *
 * `SellerHealthService` reads `ProductHealthSnapshot` for its quality
 * dimension, so product health must be written before seller health is
 * computed. The scheduler orders them, and so does the manual snapshot route.
 * There is no import cycle: it reads the table, not the service.
 */
@Module({
  controllers: [SellerIntelligenceController],
  providers: [
    DemandRadarService,
    ProductHealthService,
    SellerHealthService,
    SellerIntelligenceScheduler,
    SellerAdvisorService,
  ],
  // Exported for the seller dashboard and for admin ranking later: both want
  // a shop's health without knowing how it is computed.
  exports: [
    SellerHealthService,
    ProductHealthService,
    DemandRadarService,
    SellerAdvisorService,
  ],
})
export class SellerIntelligenceModule {}
