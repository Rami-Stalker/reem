import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { NotificationsService } from './notifications.service';
import { NotificationQueryDto } from './dto/notification-query.dto';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';
import {
  CreateCampaignDto,
  DispatchNotificationDto,
  RegisterPushTokenDto,
  TrackNotificationEventDto,
  UnregisterPushTokenDto,
  UpdateCampaignStatusDto,
} from './dto/notification-engine.dto';

/**
 * Her own inbox, and the preferences that govern what reaches it.
 *
 * Every handler passes the id from her access token to a service that filters
 * on it. The admin campaign routes further down carry their own `@Roles` and
 * are judged by those instead.
 *
 * Undeclared, the guard's fail-closed default refused the lot: the bell in the
 * app header, the unread badge, marking a notification read, registering a
 * push token. Each answered 403 to the account they belonged to.
 */
/**
 * Who may push to the user base. Support staff can read the analytics but not
 * send: a dispatch or a campaign reaches up to every account on the platform,
 * and that is not a power a support seat should carry.
 */
const BROADCAST_ROLES = [UserRole.SUPER_ADMIN, UserRole.ADMIN] as const;

@SelfScoped(
  'the inbox, the unread count, the preferences and every read receipt are '
  + "filtered on the caller's own user id",
)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  list(
    @CurrentUser('id') userId: string,
    @Query() query: NotificationQueryDto,
  ) {
    return this.notifications.list(userId, query, query.unreadOnly);
  }

  @Get('unread-count')
  unreadCount(@CurrentUser('id') userId: string) {
    return this.notifications.unreadCount(userId);
  }

  @Get('preferences')
  preferences(@CurrentUser('id') userId: string) {
    return this.notifications.getPreferences(userId);
  }

  @Patch('preferences')
  updatePreferences(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdatePreferencesDto,
  ) {
    return this.notifications.updatePreferences(userId, dto);
  }

  @Post('push-tokens')
  @HttpCode(HttpStatus.OK)
  registerPushToken(
    @CurrentUser() user: AuthUser,
    @Body() dto: RegisterPushTokenDto,
  ) {
    // Tied to this sign-in, so revoking the session silences the handset.
    return this.notifications.registerPushToken(user.id, dto, user.sessionId);
  }

  /**
   * This handset is going quiet — she signed out, or revoked the permission.
   *
   * A POST rather than a DELETE with a body, because the token is several
   * hundred characters and belongs nowhere near a URL: a query string is the
   * one part of a request every proxy on the way writes into its access log.
   */
  @Post('push-tokens/unregister')
  @HttpCode(HttpStatus.OK)
  unregisterPushToken(
    @CurrentUser('id') userId: string,
    @Body() dto: UnregisterPushTokenDto,
  ) {
    return this.notifications.unregisterPushToken(userId, dto.token);
  }

  @Post('read-all')
  @HttpCode(HttpStatus.OK)
  markAllRead(@CurrentUser('id') userId: string) {
    return this.notifications.markAllRead(userId);
  }

  @Post(':id/read')
  @HttpCode(HttpStatus.OK)
  markRead(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.notifications.markRead(userId, id);
  }

  /**
   * A read receipt for one message.
   *
   * Scoped to the caller: the delivery id used to be taken on trust, so any
   * signed-in account could mark any other woman's notification opened,
   * clicked, or failed — and the campaign analytics an operator reads are
   * built from exactly those rows.
   */
  @Post('deliveries/:id/track')
  @HttpCode(HttpStatus.OK)
  track(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: TrackNotificationEventDto,
  ) {
    return this.notifications.trackDelivery(userId, id, dto);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Get('admin/analytics')
  adminAnalytics() {
    return this.notifications.analytics();
  }

  @Roles(...BROADCAST_ROLES)
  @Post('admin/dispatch')
  @HttpCode(HttpStatus.OK)
  dispatch(
    @CurrentUser('id') actorId: string,
    @Body() dto: DispatchNotificationDto,
  ) {
    return this.notifications.dispatch(actorId, dto);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Get('admin/campaigns')
  campaigns() {
    return this.notifications.listCampaigns();
  }

  @Roles(...BROADCAST_ROLES)
  @Post('admin/campaigns')
  @HttpCode(HttpStatus.CREATED)
  createCampaign(
    @CurrentUser('id') actorId: string,
    @Body() dto: CreateCampaignDto,
  ) {
    return this.notifications.createCampaign(actorId, dto);
  }

  @Roles(...BROADCAST_ROLES)
  @Patch('admin/campaigns/:id/status')
  updateCampaignStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCampaignStatusDto,
  ) {
    return this.notifications.updateCampaignStatus(id, dto);
  }

  @Roles(...BROADCAST_ROLES)
  @Post('admin/campaigns/:id/run')
  @HttpCode(HttpStatus.OK)
  runCampaign(@Param('id', ParseUUIDPipe) id: string) {
    return this.notifications.runCampaign(id);
  }
}
