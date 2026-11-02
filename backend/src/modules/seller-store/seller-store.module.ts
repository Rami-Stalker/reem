import { Module } from '@nestjs/common';

import { NotificationsModule } from '../notifications/notifications.module';
import { PrismaModule } from '../../prisma/prisma.module';
import {
  SellerStoreController,
  SellerStoreInfoController,
  StoreMembershipsController,
} from './seller-store.controller';
import { SellerStoreService } from './seller-store.service';

@Module({
  imports: [PrismaModule, NotificationsModule],
  controllers: [
    SellerStoreController,
    StoreMembershipsController,
    SellerStoreInfoController,
  ],
  providers: [SellerStoreService],
  exports: [SellerStoreService],
})
export class SellerStoreModule {}
