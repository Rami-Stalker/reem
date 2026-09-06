import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { CodFactsService } from './cod-facts.service';
import { CodTrustAdminService } from './cod-trust.admin.service';
import { CodTrustService } from './cod-trust.service';

/**
 * The cash-on-delivery trust engine.
 *
 * Imported by orders (which asks it whether to send a parcel out on credit)
 * and by delivery (which tells it how the parcel ended). It imports auth for
 * the OTP challenge and the audit log, and nothing else — the engine reads
 * commerce rows through Prisma directly rather than through the services that
 * own them, because every one of those services would eventually want to ask
 * the engine a question back.
 */
@Module({
  imports: [AuthModule],
  providers: [CodFactsService, CodTrustService, CodTrustAdminService],
  exports: [CodTrustService, CodTrustAdminService],
})
export class CodTrustModule {}
