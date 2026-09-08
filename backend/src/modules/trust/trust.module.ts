import { Module } from '@nestjs/common';
import { TrustAdminController } from './trust.admin.controller';
import { TrustFactsService } from './trust-facts.service';
import { TrustService } from './trust.service';

/**
 * Trust & safety.
 *
 * Deliberately has no dependency on the modules it reads. It watches reviews,
 * returns and accounts through Prisma rather than through the reputation,
 * returns or auth services, so that nothing it finds can change how those
 * behave. A scorer wired into the thing it scores is a scorer that eventually
 * starts making decisions nobody signed off.
 */
@Module({
  controllers: [TrustAdminController],
  providers: [TrustService, TrustFactsService],
  exports: [TrustService],
})
export class TrustModule {}
