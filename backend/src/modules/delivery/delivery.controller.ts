import { Body, Controller, Get, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
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
  @Post('quote')
  @HttpCode(HttpStatus.OK)
  quote(@Body() dto: DeliveryQuoteDto) {
    return this.delivery.quote(dto.governorate, dto.subtotal ?? 0);
  }
}
