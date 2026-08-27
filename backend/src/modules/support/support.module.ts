import { Module } from '@nestjs/common';

import { PrismaModule } from '../../prisma/prisma.module';
import { SupportController } from './support.controller';
import { SupportService } from './support.service';

/**
 * Support conversations. The admin console's own read-and-triage routes stay
 * in `AdminModule`; this is the half that was missing — the way in.
 */
@Module({
  imports: [PrismaModule],
  controllers: [SupportController],
  providers: [SupportService],
  exports: [SupportService],
})
export class SupportModule {}
