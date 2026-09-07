import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { AppPermission } from '../../common/permissions';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { serializeFeedContent } from '../../common/serializers';
import { ContentModerationService } from './moderation/content-moderation.service';
import {
  AdminContentQueryDto,
  RemoveContentDto,
  RemoveCommentDto,
} from './dto/social.dto';

/**
 * The moderator's view of the whole social platform.
 *
 * Unlike every other read on the platform this one is **not** filtered by
 * visibility — that is the point of the screen. A moderator sees a private
 * woman's page, content already taken down, and everything anybody has
 * complained about, because a queue that only shows what a shopper can see is
 * a queue that cannot answer a report.
 */
@Authorize({
  action: 'moderate',
  resource: 'content',
  roles: [
    UserRole.SUPER_ADMIN,
    UserRole.OPERATIONS_ADMIN,
    UserRole.CONTENT_MODERATOR,
    UserRole.ADMIN,
  ],
  permissions: [AppPermission.contentModerate],
})
@Controller('admin/content')
export class AdminContentController {
  constructor(private readonly moderation: ContentModerationService) {}

  @Get()
  async list(
    @CurrentUser() user: AuthUser,
    @Query() query: AdminContentQueryDto,
  ) {
    const result = await this.moderation.list(user, {
      page: query.page,
      limit: query.limit,
      skip: query.skip,
      content_type: query.content_type,
      author_kind: query.author_kind,
      status: query.status,
      reported: query.reported,
      q: query.q,
    });
    // The admin envelope — `items` / `has_more`, not `data` / `pagination` —
    // because that is what every other `/admin` list speaks and what
    // `AdminSectionNotifier` on the client already pages through.
    return {
      items: result.items.map((content) => serializeFeedContent(content)),
      page: query.page,
      limit: query.limit,
      total: result.total,
      has_more: query.page * query.limit < result.total,
      pending: result.pending,
    };
  }

  @Get('reports')
  async reports(@CurrentUser() user: AuthUser, @Query() page: PaginationDto) {
    const result = await this.moderation.reports(user, page);
    return {
      items: result.items,
      page: page.page,
      limit: page.limit,
      total: result.total,
      has_more: page.page * page.limit < result.total,
    };
  }

  @Get(':id/history')
  history(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.moderation.history(user, id);
  }

  /**
   * Take it down.
   *
   * The reason is required by the DTO, checked again in the service and
   * enforced a third time by a CHECK constraint on the moderation-action
   * table. Three layers for one rule, because "the admin must say why" is the
   * requirement and a rule enforced in one place is a rule with two ways
   * around it.
   */
  @Post(':id/remove')
  @HttpCode(HttpStatus.OK)
  remove(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RemoveContentDto,
  ) {
    return this.moderation.remove(user, id, dto.reason);
  }

  /** And put it back, when the report was wrong. Audited the same way. */
  @Post(':id/reinstate')
  @HttpCode(HttpStatus.OK)
  reinstate(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RemoveContentDto,
  ) {
    return this.moderation.reinstate(user, id, dto.reason);
  }

  @Post('comments/:commentId/remove')
  @HttpCode(HttpStatus.OK)
  removeComment(
    @CurrentUser() user: AuthUser,
    @Param('commentId', ParseUUIDPipe) commentId: string,
    @Body() dto: RemoveCommentDto,
  ) {
    return this.moderation.removeComment(user, commentId, dto.reason ?? '');
  }
}
