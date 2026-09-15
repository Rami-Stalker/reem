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
  Put,
  Query,
} from '@nestjs/common';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CreateCommentDto } from '../posts/dto/create-comment.dto';
import {
  EngagementBatchQueryDto,
  PickProductDto,
  ReportProductDto,
} from './dto/product-social.dto';
import { ProductSocialService } from './product-social.service';

/**
 * Likes, comments, shares and «أضيفي إلى صفحتي» on a product.
 *
 * Reading is open to a guest, like the catalogue it sits on. Every write is
 * behind the global session guard and acts on the caller's own row — a like,
 * a pick and a comment all belong to whoever made them, and removing somebody
 * else's comment goes through `assertCanManage`.
 *
 * `engagement/batch` is two path segments so it can never be read as
 * `products/:id` — the catalogue controller registers that route and would
 * refuse the word "engagement" as a malformed uuid.
 */
@SelfScoped(
  "likes, picks and comments are keyed on the caller's own id; removing another's comment is checked by assertCanManage",
)
@Controller('products')
export class ProductSocialController {
  constructor(private readonly social: ProductSocialService) {}

  @OptionalAuth()
  @Get('engagement/batch')
  async engagement(
    @Query() query: EngagementBatchQueryDto,
    @CurrentUser('id') viewerId?: string,
  ) {
    return { data: await this.social.engagement(query.ids, viewerId) };
  }

  @Put(':id/like')
  like(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.social.like(userId, id);
  }

  @Delete(':id/like')
  @HttpCode(HttpStatus.OK)
  unlike(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.social.unlike(userId, id);
  }

  @Post(':id/share')
  @HttpCode(HttpStatus.OK)
  share(@Param('id', ParseUUIDPipe) id: string) {
    return this.social.share(id);
  }

  @Put(':id/pick')
  pick(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: PickProductDto,
  ) {
    return this.social.pick(userId, id, dto.note);
  }

  @Delete(':id/pick')
  @HttpCode(HttpStatus.OK)
  unpick(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.social.unpick(userId, id);
  }

  @OptionalAuth()
  @Get(':id/comments')
  comments(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() page: PaginationDto,
  ) {
    return this.social.listComments(id, page);
  }

  @Post(':id/comments')
  @HttpCode(HttpStatus.CREATED)
  addComment(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateCommentDto,
  ) {
    return this.social.addComment(user, id, dto.content);
  }

  @Delete(':id/comments/:commentId')
  @HttpCode(HttpStatus.OK)
  removeComment(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('commentId', ParseUUIDPipe) commentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.social.removeComment(user, id, commentId);
  }

  @Post(':id/report')
  @HttpCode(HttpStatus.OK)
  report(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: ReportProductDto,
  ) {
    return this.social.report(user, id, dto.reason, dto.detail);
  }
}

/** The pieces a woman added to her page. */
@SelfScoped('reading is gated by the page owner\'s visibility inside the service')
@Controller('users')
export class UserPicksController {
  constructor(private readonly social: ProductSocialService) {}

  @OptionalAuth()
  @Get(':id/picks')
  picks(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() page: PaginationDto,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.social.picksOf(id, page, viewerId);
  }
}
