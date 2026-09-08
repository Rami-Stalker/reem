import { Controller, Get, Query } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { Public } from '../../common/decorators/public.decorator';
import { FlashSalesService } from './flash-sales.service';

class LiveSalesQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;
}

/**
 * What is on sale right now.
 *
 * Public: a flash sale that only logged-in customers can see is a flash sale
 * that cannot bring anybody in, which is most of what one is for.
 */
@Controller('flash-sales')
export class FlashSalesController {
  constructor(private readonly sales: FlashSalesService) {}

  @Public()
  @Get()
  live(@Query() query: LiveSalesQueryDto) {
    return this.sales.live(query.limit ?? 20);
  }
}
