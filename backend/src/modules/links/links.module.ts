import { Module } from '@nestjs/common';
import { AppLinksService } from './app-links.service';
import { LinksController } from './links.controller';
import { SharePreviewService } from './share-preview.service';

/**
 * Shareable links: the landing pages, and the two files that let a phone open
 * them in the app instead.
 *
 * Registered **last** in `AppModule`. `LinksController` has no controller
 * prefix — its routes are `/product/:id`, `/p/:id`, `/user/:id` and the bare
 * `/` — so registering it earlier would let a one-segment pattern here shadow
 * an API route added later under a similar name. Last means every JSON
 * endpoint on the platform is matched first, and these only answer what nothing
 * else claimed.
 */
@Module({
  controllers: [LinksController],
  providers: [SharePreviewService, AppLinksService],
  exports: [SharePreviewService],
})
export class LinksModule {}
