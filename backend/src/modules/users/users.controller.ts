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
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { ProfileOverviewService } from './profile-overview.service';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { SetProfileVisibilityDto } from '../commerce-content/dto/social.dto';

@SelfScoped(
  "public profiles are public; anything that writes is scoped to the caller's own account",
)
@Controller('users')
export class UsersController {
  constructor(
    private readonly users: UsersService,
    private readonly profileOverview: ProfileOverviewService,
  ) {}

  @Get('me')
  getMe(@CurrentUser('id') userId: string) {
    return this.users.getMe(userId);
  }

  /**
   * Everything her profile centre renders, in one call.
   *
   * The screen was built against a mock and shipped unconnected, so the counts
   * and balances it showed were invented. They are read from her own rows now.
   */
  @Get('me/overview')
  overview(@CurrentUser('id') userId: string) {
    return this.profileOverview.forUser(userId);
  }

  @Patch('me')
  updateMe(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.users.updateMe(userId, dto);
  }

  /**
   * «حسابي عام» — she chooses whether her page can be looked at and followed.
   *
   * Off by default (Q15: profile visibility is the customer's own choice), and
   * the single switch that turns a shopper into somebody with an audience.
   */
  @Patch('me/profile-visibility')
  @HttpCode(HttpStatus.OK)
  setProfileVisibility(
    @CurrentUser('id') userId: string,
    @Body() dto: SetProfileVisibilityDto,
  ) {
    return this.users.setProfileVisibility(userId, dto.is_public);
  }

  /**
   * A page anyone may open — a boutique's shopfront above all, which is what a
   * shared link lands on. It used to demand a signed-in account, so a visitor
   * browsing as a guest got «صار في غلط» on every seller and shopper page she
   * tapped. A closed customer page still says only that it is closed: what is
   * readable is decided by the owner's visibility, not by who is asking.
   */
  @OptionalAuth()
  @Get(':id')
  getProfile(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.users.getProfile(id, viewerId);
  }

  @OptionalAuth()
  @Get(':id/followers')
  followers(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.listFollowers(id);
  }

  @OptionalAuth()
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
