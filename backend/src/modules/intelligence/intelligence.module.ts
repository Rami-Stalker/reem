import { Module } from '@nestjs/common';
import { GraphModule } from '../graph/graph.module';
import { IntelligenceController } from './intelligence.controller';
import { SellerOpportunityService } from './seller-opportunity.service';
import { ShopperIntelligenceService } from './shopper-intelligence.service';
import { SizeFitService } from './size-fit.service';

/**
 * Ohara Intelligence.
 *
 * The layer that turns the graph into sentences. Two audiences, one graph:
 * `ShopperIntelligenceService` answers "what should *she* know about this
 * product", `SellerOpportunityService` answers "what should *the shop* know
 * about the market".
 *
 * Deliberately thin. Every judgement lives in `kernel/`, which is pure, so the
 * reasoning behind any sentence on any screen can be re-run without a database
 * and argued with without reading a query.
 *
 * No LLM anywhere in it. The structure would take one — the verdict codes are
 * exactly the input a model would need to phrase things more warmly — but
 * nothing here waits on a model to decide *what* is true, and that is the line
 * this phase keeps.
 */
@Module({
  imports: [GraphModule],
  controllers: [IntelligenceController],
  providers: [ShopperIntelligenceService, SellerOpportunityService, SizeFitService],
  exports: [ShopperIntelligenceService, SellerOpportunityService],
})
export class IntelligenceModule {}
