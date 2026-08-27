import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { AppPermission } from '../../common/permissions';
import { CommerceContentService } from './commerce-content.service';
import { ModerateCommerceContentDto } from './dto/commerce-content.dto';

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
export class AdminCommerceContentController {
  constructor(private readonly content: CommerceContentService) {}

  @Post(':id/moderation')
  @HttpCode(HttpStatus.OK)
  moderate(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ModerateCommerceContentDto,
  ) {
    return this.content.moderate(user, id, dto);
  }
}
