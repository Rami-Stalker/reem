import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
} from '@nestjs/common';
import { Currency } from '@prisma/client';
import { Public } from '../../common/decorators/public.decorator';
import { Money } from '../../common/money';
import { DeliveryService } from './delivery.service';
import { DeliveryQuoteDto } from './dto/delivery-quote.dto';

@Controller('delivery')
export class DeliveryController {
  constructor(private readonly delivery: DeliveryService) {}

  @Public()
  @Get('governorates')
  governorates() {
    return this.delivery.listGovernorates();
  }

  @Public()
  @Get('zones')
  zones() {
    return this.delivery.listZones();
  }

  @Public()
  @Post('quote')
  @HttpCode(HttpStatus.OK)
  async quote(@Body() dto: DeliveryQuoteDto) {
    const currency = dto.currency ?? Currency.SYP;
    const quote = await this.delivery.quote({
      governorate: dto.governorate,
      district: dto.district ?? null,
      isRural: dto.is_rural ?? false,
      isExpress: dto.is_express ?? false,
      subtotal: dto.subtotal ? Money.of(dto.subtotal, currency) : undefined,
    });

    return {
      governorate: dto.governorate,
      district: dto.district ?? null,
      delivery_fee: quote.fee.toJSON(),
      free_shipping: quote.isFree,
      eta_hours_min: quote.etaHoursMin,
      eta_hours_max: quote.etaHoursMax,
      estimated_delivery_at: quote.estimatedDeliveryAt.toISOString(),
    };
  }
}
