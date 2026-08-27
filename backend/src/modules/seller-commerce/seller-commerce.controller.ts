import { Controller, Get } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { AppPermission } from '../../common/permissions';
import { SellerCommerceService } from './seller-commerce.service';

/**
 * `requireSellerVerified` matters more here since approval stopped being a
 * login gate: an applicant whose file is still pending now holds a normal
 * session, so every seller surface has to state for itself that it is for
 * approved sellers. The other five seller controllers already did; this one
 * was the gap, and it exposes the store's revenue and order figures.
 */
@Authorize({
  action: 'read',
  resource: 'seller',
  roles: [UserRole.SELLER],
  permissions: [AppPermission.analyticsRead],
  requireSellerVerified: true,
})
@Controller('seller/commerce')
export class SellerCommerceController {
  constructor(private readonly sellerCommerce: SellerCommerceService) {}

  @Get('overview')
  overview(@CurrentUser() user: AuthUser) {
    return this.sellerCommerce.overview(user);
  }
}
