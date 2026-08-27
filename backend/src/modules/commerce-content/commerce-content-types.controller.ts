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
import { AppPermission } from '../../common/permissions';
import { CommerceContentService } from './commerce-content.service';
import { RegisterContentTypeDto } from './dto/content-type.dto';

@Controller('content-types')
export class CommerceContentTypesController {
  constructor(private readonly content: CommerceContentService) {}

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
