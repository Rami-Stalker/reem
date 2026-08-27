import { Module } from '@nestjs/common';
import { DiscoveryController } from './discovery.controller';
import { DiscoveryService } from './discovery.service';
import { HomeContentService } from './home-content.service';
import { DiscoveryRepository } from './discovery.repository';

@Module({
  controllers: [DiscoveryController],
  providers: [DiscoveryService, HomeContentService, DiscoveryRepository],
  exports: [DiscoveryService],
})
export class DiscoveryModule {}
