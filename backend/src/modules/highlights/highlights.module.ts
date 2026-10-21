import { Module } from '@nestjs/common';

import { HighlightsController } from './highlights.controller';
import { HighlightsService } from './highlights.service';

/// «الأبرز». Its own module rather than a corner of `StoriesModule`: a
/// highlight outlives the story it holds, is owned by a person rather than by
/// a boutique, and is read by the profile rather than by the tray.
@Module({
  controllers: [HighlightsController],
  providers: [HighlightsService],
  exports: [HighlightsService],
})
export class HighlightsModule {}
