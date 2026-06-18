import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  getMe(@CurrentUser('id') userId: string) {
    return this.users.getMe(userId);
  }

  @Patch('me')
  updateMe(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.users.updateMe(userId, dto);
  }

  @Get(':id')
  getProfile(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') viewerId: string,
  ) {
    return this.users.getProfile(id, viewerId);
  }

  @Get(':id/followers')
  followers(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.listFollowers(id);
  }

  @Get(':id/following')
  following(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.listFollowing(id);
  }

  @Post(':id/follow')
  @HttpCode(HttpStatus.OK)
  follow(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') me: string,
  ) {
    return this.users.follow(me, id);
  }

  @Delete(':id/follow')
  @HttpCode(HttpStatus.OK)
  unfollow(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') me: string,
  ) {
    return this.users.unfollow(me, id);
  }
}
