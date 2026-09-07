import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Patch,
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
import { CommerceContentService } from './commerce-content.service';
import {
  CreateCommerceContentDto,
  SellerContentQueryDto,
  UpdateCommerceContentDto,
} from './dto/commerce-content.dto';

/**
 * Publishing, for whoever is publishing.
 *
 * This is `/seller/content` promoted to a role-neutral surface. The old one
 * still answers — nothing that exists should break — but it carried
 * `roles: [SELLER]` and `requireSellerVerified: true`, which made customer
 * authoring impossible by construction rather than by decision.
 *
 * What a role may *do* here is not decided by the route. It is decided by the
 * content type's `audiences` capability, by the tag policy, and by the review
 * gate — all of them data or pure functions, all of them checked in the
 * service. The route only asks "is she signed in and allowed to author at
 * all".
 */
@Authorize(
  {
    action: 'author',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentAuthor],
  },
  {
    action: 'moderate',
    resource: 'content',
    roles: [
      UserRole.SUPER_ADMIN,
      UserRole.OPERATIONS_ADMIN,
      UserRole.CONTENT_MODERATOR,
      UserRole.ADMIN,
    ],
    permissions: [AppPermission.contentManage],
  },
)
@Controller('content')
export class ContentAuthoringController {
  constructor(private readonly content: CommerceContentService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateCommerceContentDto) {
    return this.content.create(user, dto);
  }

  /**
   * Her own content, in every state.
   *
   * Route-ordered before `:id` deliberately — `mine` is not a uuid, but the
   * `ParseUUIDPipe` on the other route would answer a 400 rather than fall
   * through, and the 400 would read as a bug in the client.
   */
  @Get('mine')
  list(@CurrentUser() user: AuthUser, @Query() query: SellerContentQueryDto) {
    return this.content.listMine(user, query);
  }

  @Get('mine/:id')
  get(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.content.getMine(user, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCommerceContentDto,
  ) {
    return this.content.update(user, id, dto);
  }

  @Post(':id/publish')
  @HttpCode(HttpStatus.OK)
  publish(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.content.publish(user, id);
  }

  @Post(':id/archive')
  @HttpCode(HttpStatus.OK)
  archive(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.content.archive(user, id);
  }

  /** Her own deletion, which is not a takedown and is never confused with one. */
  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.content.deleteOwn(user, id);
  }

  @Post(':id/rollback/:version')
  @HttpCode(HttpStatus.OK)
  rollback(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('version', ParseIntPipe) version: number,
  ) {
    return this.content.rollback(user, id, version);
  }
}
