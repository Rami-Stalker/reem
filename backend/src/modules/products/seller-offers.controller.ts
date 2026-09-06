import {
  Body,
  Controller,
  DefaultValuePipe,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { SellerOffersService } from './seller-offers.service';
import {
  AdjustOfferStockDto,
  CreateOfferDto,
  UpdateOfferDto,
} from './dto/offer.dto';
import { SellerProductQueryDto } from './dto/seller-product-query.dto';

/**
 * A seller's listings: price, stock and fulfilment terms for products in the
 * shared catalog. Ownership is enforced per offer inside the service.
 */
@Authorize(
  {
    action: 'manage',
    resource: 'product',
    roles: [UserRole.SELLER],
    permissions: [AppPermission.productManage],
    requireSellerVerified: true,
  },
  {
    action: 'moderate',
    resource: 'product',
    roles: [
      UserRole.SUPER_ADMIN,
      UserRole.OPERATIONS_ADMIN,
      UserRole.CONTENT_MODERATOR,
      UserRole.ADMIN,
    ],
    permissions: [AppPermission.productManage],
  },
)
@Controller('seller/offers')
export class SellerOffersController {
  constructor(private readonly offers: SellerOffersService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateOfferDto) {
    return this.offers.create(user, dto);
  }

  @Get()
  listMine(
    @CurrentUser() user: AuthUser,
    @Query() query: SellerProductQueryDto,
  ) {
    return this.offers.listMine(user, query);
  }

  @Get('low-stock')
  lowStock(
    @CurrentUser() user: AuthUser,
    @Query('threshold', new DefaultValuePipe(5), ParseIntPipe)
    threshold: number,
  ) {
    return this.offers.lowStock(user, threshold);
  }

  @Get(':id')
  getMine(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.offers.getMine(user, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateOfferDto,
  ) {
    return this.offers.update(user, id, dto);
  }

  @Post(':id/stock')
  @HttpCode(HttpStatus.OK)
  adjustStock(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AdjustOfferStockDto,
  ) {
    return this.offers.adjustStock(user, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  remove(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.offers.remove(user, id);
  }
}
