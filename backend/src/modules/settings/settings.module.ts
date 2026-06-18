import { Module } from '@nestjs/common';
import { SettingsService } from './settings.service';
import {
  AddressesController,
  PaymentMethodsController,
} from './settings.controller';

@Module({
  controllers: [AddressesController, PaymentMethodsController],
  providers: [SettingsService],
})
export class SettingsModule {}
