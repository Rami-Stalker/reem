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
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { SellerProductsService } from './seller-products.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { CreateVariantDto, UpdateVariantDto } from './dto/product-variant.dto';

/**
 * Authoring CANONICAL catalog entries. Price, stock and fulfilment terms are
 * not here — they belong to the seller's offer (`/seller/offers`).
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
@Controller('seller/products')
export class SellerProductsController {
  constructor(private readonly seller: SellerProductsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateProductDto) {
    return this.seller.create(user, dto);
  }


  @Get(':id')
  getMine(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.seller.getMine(user, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateProductDto,
  ) {
    return this.seller.update(user, id, dto);
  }




  @Post(':id/variants')
  @HttpCode(HttpStatus.CREATED)
  addVariant(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateVariantDto,
  ) {
    return this.seller.addVariant(user, id, dto);
  }

  @Patch(':id/variants/:variantId')
  updateVariant(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('variantId', ParseUUIDPipe) variantId: string,
    @Body() dto: UpdateVariantDto,
  ) {
    return this.seller.updateVariant(user, id, variantId, dto);
  }

  @Delete(':id/variants/:variantId')
  @HttpCode(HttpStatus.OK)
  removeVariant(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('variantId', ParseUUIDPipe) variantId: string,
  ) {
    return this.seller.removeVariant(user, id, variantId);
  }
}
