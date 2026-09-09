import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { SettingsService } from './settings.service';
import { AddressDto, UpdateAddressDto } from './dto/address.dto';
import { CreatePaymentMethodDto } from './dto/create-payment-method.dto';
import { AssuranceLevel } from '@prisma/client';
import { RequireStepUp } from '../../common/decorators/require-step-up.decorator';
import { DeviceProof } from '../../common/guards/device-proof.guard';

@SelfScoped(
  "preferences, addresses and notification settings are all keyed on the caller's id",
)
@Controller('addresses')
export class AddressesController {
  constructor(private readonly settings: SettingsService) {}

  @Get()
  list(@CurrentUser('id') userId: string) {
    return this.settings.listAddresses(userId);
  }

  // On this platform the stored delivery address is a woman's home. Writing
  // one is therefore not an ordinary profile edit: it requires a request that
  // demonstrably came from her own handset, not from a stolen bearer token.
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL2, 'address_write')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser('id') userId: string, @Body() dto: AddressDto) {
    return this.settings.createAddress(userId, dto);
  }

  // Editing and deleting carry the same proof as creating: changing where a
  // parcel is sent is exactly as sensitive as saying so the first time.
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL2, 'address_write')
  @Patch(':id')
  update(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAddressDto,
  ) {
    return this.settings.updateAddress(userId, id, dto);
  }

  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL2, 'address_write')
  @Delete(':id')
  remove(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.settings.deleteAddress(userId, id);
  }

  /**
   * Choosing which saved address is the default moves no data and reveals
   * nothing, so it does not carry the step-up the write routes do.
   */
  @Post(':id/default')
  @HttpCode(HttpStatus.OK)
  setDefault(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.settings.setDefaultAddress(userId, id);
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
