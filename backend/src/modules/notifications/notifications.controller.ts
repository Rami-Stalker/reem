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
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { NotificationsService } from './notifications.service';
import { NotificationQueryDto } from './dto/notification-query.dto';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';
import {
  CreateCampaignDto,
  DispatchNotificationDto,
  RegisterPushTokenDto,
  TrackNotificationEventDto,
  UpdateCampaignStatusDto,
} from './dto/notification-engine.dto';

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
    @CurrentUser('id') userId: string,
    @Body() dto: RegisterPushTokenDto,
  ) {
    return this.notifications.registerPushToken(userId, dto);
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

  @Post('deliveries/:id/track')
  @HttpCode(HttpStatus.OK)
  track(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: TrackNotificationEventDto,
  ) {
    return this.notifications.trackDelivery(id, dto);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Get('admin/analytics')
  adminAnalytics() {
    return this.notifications.analytics();
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
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

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Post('admin/campaigns')
  @HttpCode(HttpStatus.CREATED)
  createCampaign(
    @CurrentUser('id') actorId: string,
    @Body() dto: CreateCampaignDto,
  ) {
    return this.notifications.createCampaign(actorId, dto);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Patch('admin/campaigns/:id/status')
  updateCampaignStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCampaignStatusDto,
  ) {
    return this.notifications.updateCampaignStatus(id, dto);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Post('admin/campaigns/:id/run')
  @HttpCode(HttpStatus.OK)
  runCampaign(@Param('id', ParseUUIDPipe) id: string) {
    return this.notifications.runCampaign(id);
  }
}
