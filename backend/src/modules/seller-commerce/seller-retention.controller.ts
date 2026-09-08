import { Controller, Get, Query } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import { SellerCrmService } from './seller-crm.service';

class QuietSellersQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(7)
  @Max(365)
  quiet_days?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;
}

/**
 * Boutiques going quiet.
 *
 * Seller retention was the mirror image of the customer gap and equally
 * unbuilt: a marketplace loses sellers the way it loses customers — gradually,
 * and invisibly, because nothing counts. Ordered by lifetime volume, so the
 * shops worth a phone call come first.
 */
@Authorize({
  action: 'read',
  resource: 'analytics',
  roles: [UserRole.SUPER_ADMIN, UserRole.OPERATIONS_ADMIN, UserRole.ADMIN],
  permissions: [AppPermission.analyticsRead],
})
@Controller('admin/sellers/retention')
export class SellerRetentionController {
  constructor(private readonly crm: SellerCrmService) {}

  @Get('quiet')
  async quiet(@Query() query: QuietSellersQueryDto) {
    const rows = await this.crm.quietSellers({
      quietDays: query.quiet_days ?? 45,
      limit: query.limit ?? 50,
    });
    return {
      quiet_days: query.quiet_days ?? 45,
      data: rows.map((row) => ({
        seller_id: row.seller_id,
        name: row.name,
        username: row.username,
        live_listings: row.live_listings,
        lifetime_orders: row.lifetime_orders,
        last_order_at: row.last_order_at?.toISOString() ?? null,
        last_listed_at: row.last_listed_at?.toISOString() ?? null,
      })),
    };
  }
}
