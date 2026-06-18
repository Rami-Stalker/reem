import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SettingsService } from './settings.service';
import { CreateAddressDto } from './dto/create-address.dto';
import { CreatePaymentMethodDto } from './dto/create-payment-method.dto';

@Controller('addresses')
export class AddressesController {
  constructor(private readonly settings: SettingsService) {}

  @Get()
  list(@CurrentUser('id') userId: string) {
    return this.settings.listAddresses(userId);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser('id') userId: string, @Body() dto: CreateAddressDto) {
    return this.settings.createAddress(userId, dto);
  }
}

// Coupons, rewards, and notifications are owned by the RewardsModule and
// NotificationsModule respectively.

@Controller('payment-methods')
export class PaymentMethodsController {
  constructor(private readonly settings: SettingsService) {}

  @Get()
  list(@CurrentUser('id') userId: string) {
    return this.settings.listPaymentMethods(userId);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreatePaymentMethodDto,
  ) {
    return this.settings.createPaymentMethod(userId, dto);
  }
}
