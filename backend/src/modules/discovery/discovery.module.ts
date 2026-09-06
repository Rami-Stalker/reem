import { Module } from '@nestjs/common';
import { GraphModule } from '../graph/graph.module';
import { DiscoveryController } from './discovery.controller';
import { DiscoveryService } from './discovery.service';
import { HomeContentService } from './home-content.service';
import { DiscoveryRepository } from './discovery.repository';

@Module({
  controllers: [DiscoveryController],
  imports: [GraphModule],
  providers: [DiscoveryService, HomeContentService, DiscoveryRepository],
  exports: [DiscoveryService],
})
export class DiscoveryModule {}
