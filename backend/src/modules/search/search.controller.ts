import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { SearchService } from './search.service';
import {
  ProductSearchDto,
  SearchClickDto,
  SearchQueryDto,
} from './dto/search-query.dto';

@SelfScoped(
  "search is public; history is read and cleared for the caller's own id",
)
@Controller('search')
export class SearchController {
  constructor(private readonly search: SearchService) {}

  @OptionalAuth()
  @Get()
  unified(
    @Query('q') q: string | undefined,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.search.unified(q, viewerId);
  }

  @OptionalAuth()
  @Get('products')
  products(
    @Query() dto: ProductSearchDto,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.search.searchProducts(dto, viewerId);
  }

  @OptionalAuth()
  @Get('sellers')
  sellers(@Query() dto: SearchQueryDto) {
    return this.search.searchSellers(dto.q, dto);
  }

  /** Shoppers with an open page. */
  @OptionalAuth()
  @Get('users')
  users(@Query() dto: SearchQueryDto) {
    return this.search.searchCustomers(dto.q, dto);
  }

  @OptionalAuth()
  @Get('posts')
  posts(
    @Query() dto: SearchQueryDto,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.search.searchPosts(dto.q, viewerId, dto);
  }

  @Public()
  @Get('suggestions')
  suggestions(@Query('q') q: string | undefined) {
    return this.search.suggestions(q);
  }

  @Public()
  @Get('trending')
  trending() {
    return this.search.trending();
  }

  /**
   * She opened a product from a result list. Feeds Search Intelligence only;
   * nothing is returned and nothing about ranking or money reads it directly.
   */
  @OptionalAuth()
  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Post('clicks')
  @HttpCode(HttpStatus.NO_CONTENT)
  click(
    @Body() dto: SearchClickDto,
    @CurrentUser('id') viewerId?: string,
  ): void {
    this.search.recordResultClick({
      query: dto.q,
      productId: dto.product_id,
      userId: viewerId ?? null,
    });
  }

  // ── Authenticated history ──────────────────────────────────────────────

  @Get('recent')
  recent(@CurrentUser('id') userId: string) {
    return this.search.recent(userId);
  }

  @Delete('recent')
  @HttpCode(HttpStatus.OK)
  clearRecent(@CurrentUser('id') userId: string) {
    return this.search.clearRecent(userId);
  }

  @Delete('recent/:id')
  @HttpCode(HttpStatus.OK)
  removeRecent(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.search.removeRecent(userId, id);
  }
}
