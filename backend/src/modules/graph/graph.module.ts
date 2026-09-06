import { Module } from '@nestjs/common';
import { AffinityBuilderService } from './projection/affinity-builder.service';
import { GraphProjectorService } from './projection/graph-projector.service';
import { GraphQueryService } from './graph-query.service';
import { GraphScheduler } from './graph.scheduler';

/**
 * Reem Commerce Graph.
 *
 * A projection layer, not a source of truth: everything in it is derived from
 * tables that already exist, and the whole thing could be dropped and rebuilt.
 * That is what makes it safe for other modules to depend on and safe to change
 * when the shape turns out wrong.
 *
 * Exports the *query* service rather than the projectors, because reading the
 * graph is what other features want and writing it is this module's own
 * business.
 */
@Module({
  providers: [
    GraphProjectorService,
    AffinityBuilderService,
    GraphQueryService,
    GraphScheduler,
  ],
  exports: [GraphQueryService, GraphProjectorService, AffinityBuilderService],
})
export class GraphModule {}
