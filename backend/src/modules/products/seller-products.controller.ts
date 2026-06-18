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
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { SellerProductsService } from './seller-products.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { SellerProductQueryDto } from './dto/seller-product-query.dto';
import { CreateVariantDto, UpdateVariantDto } from './dto/product-variant.dto';
import { AdjustStockDto, SetProductStatusDto } from './dto/inventory.dto';

/**
 * Seller storefront management. Every route requires the SELLER (or ADMIN) role
 * AND ownership of the target product — enforced server-side in the service.
 */
@Roles(UserRole.SELLER, UserRole.ADMIN)
@Controller('seller/products')
export class SellerProductsController {
  constructor(private readonly seller: SellerProductsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateProductDto) {
    return this.seller.create(user, dto);
  }

  @Get()
  listMine(
    @CurrentUser() user: AuthUser,
    @Query() query: SellerProductQueryDto,
  ) {
    return this.seller.listMine(user, query);
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

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  remove(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.seller.remove(user, id);
  }

  @Patch(':id/status')
  setStatus(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetProductStatusDto,
  ) {
    return this.seller.setStatus(user, id, dto.status);
  }

  @Post(':id/stock')
  @HttpCode(HttpStatus.OK)
  adjustStock(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AdjustStockDto,
  ) {
    return this.seller.adjustStock(user, id, dto.delta);
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
