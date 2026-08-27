import {
  Body,
  Controller,
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
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { AppPermission } from '../../common/permissions';
import { CommerceContentService } from './commerce-content.service';
import {
  CreateCommerceContentDto,
  SellerContentQueryDto,
  UpdateCommerceContentDto,
} from './dto/commerce-content.dto';

@Authorize(
  {
    action: 'manage',
    resource: 'content',
    roles: [UserRole.SELLER],
    permissions: [AppPermission.contentManage],
    requireSellerVerified: true,
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
@Controller('seller/content')
export class SellerCommerceContentController {
  constructor(private readonly content: CommerceContentService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateCommerceContentDto) {
    return this.content.create(user, dto);
  }

  @Get()
  list(@CurrentUser() user: AuthUser, @Query() query: SellerContentQueryDto) {
    return this.content.listMine(user, query);
  }

  @Get(':id')
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
  publish(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.content.publish(user, id);
  }

  @Post(':id/archive')
  @HttpCode(HttpStatus.OK)
  archive(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.content.archive(user, id);
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

  @Get(':id/analytics')
  analytics(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.content.analytics(user, id);
  }
}
