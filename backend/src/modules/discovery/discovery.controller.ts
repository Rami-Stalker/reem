import { Controller, Get, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { DiscoveryService } from './discovery.service';
import { HomeContentService } from './home-content.service';
import { DiscoveryQueryDto } from './dto/discovery-query.dto';

/**
 * Product discovery. All routes are public-but-personalised (`is_liked` when
 * signed in) and cache-backed.
 */
@OptionalAuth()
@Controller('discovery')
export class DiscoveryController {
  constructor(
    private readonly discovery: DiscoveryService,
    private readonly homeContentService: HomeContentService,
  ) {}

  @Get('home')
  home(@CurrentUser('id') viewerId?: string) {
    return this.discovery.home(viewerId);
  }

  /**
   * Everything the customer's home page renders, in one call.
   *
   * Separate from `home` above, which is the product-collection feed. This is
   * the editorial page — banners, categories, deals, her cart, her points —
   * and it exists because the screen was built against a mock and shipped
   * without ever being connected to anything.
   */
  @Get('home-content')
  homeContent(@CurrentUser('id') viewerId?: string) {
    return this.homeContentService.content(viewerId);
  }

  @Get('recommended')
  recommended(
    @Query() dto: DiscoveryQueryDto,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.discovery.recommended(dto, viewerId);
  }

  @Get('collections/:key')
  collection(
    @Param('key') key: string,
    @Query() dto: DiscoveryQueryDto,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.discovery.collection(key, dto, viewerId);
  }

  @Get('category/:category')
  category(
    @Param('category') category: string,
    @Query() dto: DiscoveryQueryDto,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.discovery.category(category, dto, viewerId);
  }

  @Get('seller/:sellerId')
  seller(
    @Param('sellerId', ParseUUIDPipe) sellerId: string,
    @Query() dto: DiscoveryQueryDto,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.discovery.seller(sellerId, dto, viewerId);
  }

  @Get('products/:id/similar')
  similar(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() dto: DiscoveryQueryDto,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.discovery.similar(id, dto, viewerId);
  }
}
