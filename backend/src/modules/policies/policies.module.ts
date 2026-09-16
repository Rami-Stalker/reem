import { Module } from '@nestjs/common';

import { PrismaModule } from '../../prisma/prisma.module';
import { PoliciesController } from './policies.controller';
import { PoliciesService } from './policies.service';
import { PolicyAdminController } from './policy-admin.controller';
import { PolicyAdminService } from './policy-admin.service';
import { PolicyBootstrap } from './policy.bootstrap';

/**
 * The policy centre: the eight documents, their versions, and the record of
 * who agreed to which.
 *
 * `PoliciesService` is exported because two other modules have to write a
 * consent inside their own transaction — registration, which must not be able
 * to create an account whose consent failed to record, and the seller
 * application, which is where the seller terms and the commissions policy are
 * actually signed.
 */
@Module({
  imports: [PrismaModule],
  controllers: [PoliciesController, PolicyAdminController],
  providers: [PoliciesService, PolicyAdminService, PolicyBootstrap],
  exports: [PoliciesService],
})
export class PoliciesModule {}
