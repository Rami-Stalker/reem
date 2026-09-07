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
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { PostsService } from './posts.service';
import { CreateCommentDto } from './dto/create-comment.dto';

/**
 * Customer-facing feed + engagement.
 *
 * Reading is open to everyone — a visitor browses the feed, a seller's wall,
 * a single post and its comments without an account, exactly like the catalog.
 * `@OptionalAuth()` still resolves the viewer when a token is present, so
 * `is_liked` / `is_saved` come back populated for signed-in users.
 *
 * Everything that writes — liking, saving, sharing, commenting, and the
 * personal "saved" list — stays behind the global guard.
 */
@Controller('posts')
export class PostsController {
  constructor(private readonly posts: PostsService) {}

  @OptionalAuth()
  @Get('feed')
  feed(@Query() page: PaginationDto, @CurrentUser('id') userId?: string) {
    return this.posts.feed(userId, page);
  }

  @Get('saved')
  saved(@CurrentUser('id') userId: string, @Query() page: PaginationDto) {
    return this.posts.saved(userId, page);
  }

  @OptionalAuth()
  @Get('seller/:sellerId')
  bySeller(
    @Param('sellerId', ParseUUIDPipe) sellerId: string,
    @Query() page: PaginationDto,
    @CurrentUser('id') userId?: string,
  ) {
    return this.posts.bySeller(sellerId, userId, page);
  }

  @OptionalAuth()
  @Get(':id')
  single(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId?: string,
  ) {
    return this.posts.single(id, userId);
  }

  @Post(':id/like')
  @HttpCode(HttpStatus.OK)
  like(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.posts.toggleLike(user, id);
  }

  @Post(':id/save')
  @HttpCode(HttpStatus.OK)
  save(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.posts.toggleSave(user, id);
  }

  @Post(':id/share')
  @HttpCode(HttpStatus.OK)
  share(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.posts.share(user, id);
  }

  @OptionalAuth()
  @Get(':id/comments')
  comments(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() page: PaginationDto,
  ) {
    return this.posts.listComments(id, page);
  }

  @Post(':id/comments')
  @HttpCode(HttpStatus.CREATED)
  addComment(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateCommentDto,
  ) {
    return this.posts.addComment(user, id, dto.content);
  }

  @Delete(':id/comments/:commentId')
  @HttpCode(HttpStatus.OK)
  deleteComment(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('commentId', ParseUUIDPipe) commentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.posts.deleteComment(user, id, commentId);
  }
}
