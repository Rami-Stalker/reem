import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module';
import { FitProfileController } from './fit/fit-profile.controller';
import { FitProfileService } from './fit/fit-profile.service';
import { ReputationController } from './reputation.controller';
import { ReputationService } from './reputation.service';

/**
 * Reviews and the standing they add up to — and, since «تقييمات من بمقاسي»,
 * the fit profile a review is compared by. The profile lives here rather than
 * in a module of its own because reviews are its only reader.
 */
@Module({
  // For checking that a review's photographs are her own uploads, and
  // claiming them once the review is saved.
  imports: [MediaModule],
  controllers: [ReputationController, FitProfileController],
  providers: [ReputationService, FitProfileService],
  exports: [ReputationService, FitProfileService],
})
export class ReputationModule {}
