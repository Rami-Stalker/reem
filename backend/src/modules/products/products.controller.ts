import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import { ProductsService } from './products.service';
import { OrderCountDto } from './dto/product-actions.dto';
import { ProductQueryDto } from './dto/product-query.dto';


@Controller('products')
export class ProductsController {
  constructor(private readonly products: ProductsService) {}

  // ── Public browsing (personalised when signed in) ────────────────────────

  @OptionalAuth()
  @Get('home')
  home(@CurrentUser('id') viewerId?: string) {
    return this.products.home(viewerId);
  }

  @OptionalAuth()
  @Get('trending')
  trending(@CurrentUser('id') viewerId?: string) {
    return this.products.trending(viewerId);
  }

  @OptionalAuth()
  @Get('new-arrivals')
  newArrivals(@CurrentUser('id') viewerId?: string) {
    return this.products.newArrivals(viewerId);
  }

  @OptionalAuth()
  @Get('featured')
  featured(@CurrentUser('id') viewerId?: string) {
    return this.products.featured(viewerId);
  }

  @OptionalAuth()
  @Get('most-loved')
  mostLoved(@CurrentUser('id') viewerId?: string) {
    return this.products.mostLoved(viewerId);
  }

  @OptionalAuth()
  @Get('top-rated')
  topRated(@CurrentUser('id') viewerId?: string) {
    return this.products.topRated(viewerId);
  }

  @OptionalAuth()
  @Get('search')
  search(@Query() query: ProductQueryDto, @CurrentUser('id') viewerId?: string) {
    return this.products.search(query, viewerId);
  }

  @OptionalAuth()
  @Get('category/:category/trending')
  categoryTrending(
    @Param('category') category: string,
    @Query() query: ProductQueryDto,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.products.byCategory(category, query, viewerId, [
      { ordersCount: 'desc' },
      { createdAt: 'desc' },
    ]);
  }

  @OptionalAuth()
  @Get('category/:category/new-arrivals')
  categoryNewArrivals(
    @Param('category') category: string,
    @Query() query: ProductQueryDto,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.products.byCategory(category, query, viewerId, [{ createdAt: 'desc' }]);
  }

  @OptionalAuth()
  @Get('category/:category')
  category(
    @Param('category') category: string,
    @Query() query: ProductQueryDto,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.products.byCategory(category, query, viewerId, [{ createdAt: 'desc' }]);
  }

  @OptionalAuth()
  @Get()
  list(@Query() query: ProductQueryDto, @CurrentUser('id') viewerId?: string) {
    return this.products.list(query, viewerId);
  }

  @OptionalAuth()
  @Get(':id')
  detail(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.products.detail(id, viewerId);
  }

  // ── Authenticated mutations (global JwtAuthGuard enforces a token) ────────

  @Post(':id/views')
  recordView(@Param('id', ParseUUIDPipe) id: string) {
    return this.products.recordView(id);
  }

  @Post(':id/orders')
  @Authorize({
    action: 'maintain',
    resource: 'product',
    roles: [
      UserRole.SUPER_ADMIN,
      UserRole.OPERATIONS_ADMIN,
      UserRole.CONTENT_MODERATOR,
      UserRole.ADMIN,
    ],
    permissions: [AppPermission.productManage],
  })
  incrementOrders(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: OrderCountDto,
  ) {
    return this.products.incrementOrders(id, dto.amount ?? 1);
  }

}
