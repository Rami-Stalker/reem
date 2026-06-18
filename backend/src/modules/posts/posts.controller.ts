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
import { PaginationDto } from '../../common/dto/pagination.dto';
import { PostsService } from './posts.service';
import { CreateCommentDto } from './dto/create-comment.dto';

/** Customer-facing feed + engagement. Any authenticated user may interact. */
@Controller('posts')
export class PostsController {
  constructor(private readonly posts: PostsService) {}

  @Get('feed')
  feed(@CurrentUser('id') userId: string, @Query() page: PaginationDto) {
    return this.posts.feed(userId, page);
  }

  @Get('saved')
  saved(@CurrentUser('id') userId: string, @Query() page: PaginationDto) {
    return this.posts.saved(userId, page);
  }

  @Get('seller/:sellerId')
  bySeller(
    @Param('sellerId', ParseUUIDPipe) sellerId: string,
    @CurrentUser('id') userId: string,
    @Query() page: PaginationDto,
  ) {
    return this.posts.bySeller(sellerId, userId, page);
  }

  @Get(':id')
  single(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.posts.single(id, userId);
  }

  @Post(':id/like')
  @HttpCode(HttpStatus.OK)
  like(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.posts.toggleLike(userId, id);
  }

  @Post(':id/save')
  @HttpCode(HttpStatus.OK)
  save(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.posts.toggleSave(userId, id);
  }

  @Post(':id/share')
  @HttpCode(HttpStatus.OK)
  share(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.posts.share(userId, id);
  }

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
    @CurrentUser('id') userId: string,
    @Body() dto: CreateCommentDto,
  ) {
    return this.posts.addComment(userId, id, dto.content);
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
