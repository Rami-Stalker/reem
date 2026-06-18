import {
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Query,
} from '@nestjs/common';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SearchService } from './search.service';
import { ProductSearchDto, SearchQueryDto } from './dto/search-query.dto';

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
