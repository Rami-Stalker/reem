import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import { RankingService } from './ranking.service';

class SweepDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(20000)
  limit?: number;
}

/**
 * Positions, and the reasons behind them.
 *
 * The explain routes matter more than the sweeps. A seller asking why her
 * dress is on page three is asking a fair question, and a marketplace that
 * cannot answer it is one whose ranking will be assumed to be for sale.
 */
@Authorize({
  action: 'manage',
  resource: 'product',
  roles: [UserRole.SUPER_ADMIN, UserRole.OPERATIONS_ADMIN, UserRole.ADMIN],
  permissions: [AppPermission.productManage],
})
@Controller('admin/ranking')
export class RankingController {
  constructor(private readonly ranking: RankingService) {}

  @Get('sellers')
  topSellers(@Query() query: SweepDto) {
    return this.ranking.topSellers(query.limit ?? 25);
  }

  @Get('products/:id')
  explainProduct(@Param('id', ParseUUIDPipe) id: string) {
    return this.ranking.explainListing(id);
  }

  @Get('sellers/:id')
  explainSeller(@Param('id', ParseUUIDPipe) id: string) {
    return this.ranking.explainSeller(id);
  }

  @Post('sweep/products')
  sweepProducts(@Body() dto: SweepDto) {
    return this.ranking.sweepListings(dto.limit ?? 2000);
  }

  @Post('sweep/sellers')
  sweepSellers(@Body() dto: SweepDto) {
    return this.ranking.sweepSellers(dto.limit ?? 1000);
  }
}
