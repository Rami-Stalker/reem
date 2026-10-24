import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DeliveryProviderKind } from '@prisma/client';

import { PrismaService } from '../../../prisma/prisma.service';

/**
 * Guarantees the platform can always move a parcel.
 *
 * Dispatch chooses among carrier accounts, and an empty table would mean every
 * packed parcel waits for a row somebody forgot to create — the exact failure
 * this subsystem exists to end. So on first boot, and only when no carrier is
 * configured at all, the in-house fleet is registered as the default provider.
 *
 * It is a floor, not a policy: the moment an operations admin adds a delivery
 * company and gives it a lower priority, that company wins, and turning the
 * in-house account off is a click. Nothing here ever overwrites a decision
 * somebody made.
 */
@Injectable()
export class DeliveryProviderBootstrap implements OnModuleInit {
  private readonly logger = new Logger(DeliveryProviderBootstrap.name);

  constructor(private readonly prisma: PrismaService) {}

  async onModuleInit(): Promise<void> {
    try {
      const configured = await this.prisma.deliveryProviderAccount.count();
      if (configured > 0) return;

      await this.prisma.deliveryProviderAccount.create({
        data: {
          code: 'internal',
          adapter: 'internal',
          displayName: 'فريق أوهارا للتوصيل',
          kind: DeliveryProviderKind.INTERNAL,
          isEnabled: true,
          isDefault: true,
          priority: 100,
          governorates: [],
          supportsTracking: true,
          supportsCancel: true,
          supportsWebhook: false,
          webhookAuth: 'NONE',
        },
      });

      this.logger.log(
        'No delivery company was configured — registered the in-house fleet as the default carrier',
      );
    } catch (error) {
      // A boot must not fail because a convenience row could not be written.
      this.logger.warn(
        `Could not verify the delivery provider table: ${(error as Error).message}`,
      );
    }
  }
}
