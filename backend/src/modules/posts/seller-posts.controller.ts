import {
  Body,
  Controller,
  Delete,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { SellerPostsService } from './seller-posts.service';
import { CreatePostDto } from './dto/create-post.dto';
import { UpdatePostDto } from './dto/update-post.dto';

/** Seller-only authoring. Customers are rejected by the AuthorizationGuard. */
@Authorize(
  {
    action: 'manage',
    resource: 'post',
    roles: [UserRole.SELLER],
    permissions: [AppPermission.postManage],
    requireSellerVerified: true,
  },
  {
    action: 'moderate',
    resource: 'post',
    roles: [
      UserRole.SUPER_ADMIN,
      UserRole.OPERATIONS_ADMIN,
      UserRole.CONTENT_MODERATOR,
      UserRole.ADMIN,
    ],
    permissions: [AppPermission.postManage],
  },
)
@Controller('seller/posts')
export class SellerPostsController {
  constructor(private readonly seller: SellerPostsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreatePostDto) {
    return this.seller.create(user, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdatePostDto,
  ) {
    return this.seller.update(user, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  remove(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.seller.remove(user, id);
  }
}
