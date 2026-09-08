import { Controller, Get, Query } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { UserRole } from '@prisma/client';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { SellerCrmService } from './seller-crm.service';

class CrmQueryDto extends PaginationDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(7)
  @Max(1095)
  window_days?: number;
}

/**
 * A boutique's own customer book.
 *
 * Scoped to her own trade by the service, from the id on the token — there is
 * no seller parameter to tamper with. She sees who bought from her, what they
 * spent and who has stopped; she does not see a phone number, and there is no
 * endpoint here that sends anything. Reaching customers goes through the
 * platform's notification rules, where a woman's own preferences are honoured.
 */
@Authorize({
  action: 'manage',
  resource: 'product',
  roles: [UserRole.SELLER],
  permissions: [AppPermission.productManage],
})
@Controller('seller/customers')
export class SellerCrmController {
  constructor(private readonly crm: SellerCrmService) {}

  @Get('overview')
  overview(@CurrentUser() user: AuthUser, @Query() query: CrmQueryDto) {
    return this.crm.overview(user.id, query.window_days);
  }

  @Get()
  async list(@CurrentUser() user: AuthUser, @Query() query: CrmQueryDto) {
    const { data, total } = await this.crm.customers(user.id, {
      limit: query.limit,
      skip: query.skip,
      windowDays: query.window_days,
    });
    return {
      data: data.map((row) => ({
        user_id: row.userId,
        name: row.name,
        username: row.username,
        orders: row.orders,
        units: row.units,
        spend: row.spend.toJSON(),
        first_order_at: row.firstOrderAt.toISOString(),
        last_order_at: row.lastOrderAt.toISOString(),
        is_repeat: row.isRepeat,
        is_lapsed: row.isLapsed,
      })),
      total,
    };
  }
}
