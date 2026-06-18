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
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { SellerStoriesService } from './seller-stories.service';
import { CreateStoryDto } from './dto/create-story.dto';

/** Seller-only story authoring + analytics (viewers, reactions, reach). */
@Roles(UserRole.SELLER, UserRole.ADMIN)
@Controller('seller/stories')
export class SellerStoriesController {
  constructor(private readonly seller: SellerStoriesService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateStoryDto) {
    return this.seller.create(user, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  remove(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.seller.remove(user, id);
  }

  @Get(':id/analytics')
  analytics(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.seller.analytics(user, id);
  }

  @Get(':id/viewers')
  viewers(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.seller.viewers(user, id);
  }
}
