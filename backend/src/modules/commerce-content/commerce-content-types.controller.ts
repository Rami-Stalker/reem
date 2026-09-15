import {
  Body,
  Controller,
  DefaultValuePipe,
  Get,
  ParseBoolPipe,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { AppPermission } from '../../common/permissions';
import { CommerceContentService } from './commerce-content.service';
import { RegisterContentTypeDto } from './dto/content-type.dto';

@Controller('content-types')
export class CommerceContentTypesController {
  constructor(private readonly content: CommerceContentService) {}

  /**
   * The kinds of thing that can be posted.
   *
   * Catalogue, not configuration: the composer reads it to draw its tabs and
   * the feed reads it to label a card, both of which happen before there is a
   * session. Registering a new type stays behind `content:type_manage` below.
   */
  @Public()
  @Get()
  list(
    @Query('include_inactive', new DefaultValuePipe(false), ParseBoolPipe)
    includeInactive: boolean,
  ) {
    return this.content.listTypes(includeInactive);
  }

  @Authorize({
    action: 'manage',
    resource: 'content',
    roles: [UserRole.SUPER_ADMIN, UserRole.OPERATIONS_ADMIN, UserRole.ADMIN],
    permissions: [AppPermission.contentTypeManage],
  })
  @Post()
  register(@Body() dto: RegisterContentTypeDto) {
    return this.content.registerType(dto);
  }
}
