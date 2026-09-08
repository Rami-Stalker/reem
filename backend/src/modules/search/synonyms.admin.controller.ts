import {
  Body,
  Controller,
  Delete,
  Get,
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
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import {
  AddSynonymTermDto,
  CreateSynonymGroupDto,
  SetSynonymActiveDto,
  UnansweredQueryDto,
} from './dto/synonyms.dto';
import { SynonymsAdminService } from './synonyms.admin.service';

/**
 * The words the catalogue does not use, and what they mean.
 *
 * Merchandising work, so it sits behind `product:manage` rather than a
 * moderation or analytics permission: adding a synonym changes what every
 * customer's search returns, which is the same weight as editing a listing.
 */
@Authorize({
  action: 'manage',
  resource: 'product',
  roles: [UserRole.SUPER_ADMIN, UserRole.OPERATIONS_ADMIN, UserRole.ADMIN],
  permissions: [AppPermission.productManage],
})
@Controller('admin/search/synonyms')
export class SynonymsAdminController {
  constructor(private readonly synonyms: SynonymsAdminService) {}

  @Get()
  list() {
    return this.synonyms.list();
  }

  /**
   * The queue this whole feature exists to serve: terms with real search
   * volume that the catalogue answered with nothing, and that no synonym
   * group covers yet.
   */
  @Get('unanswered')
  unanswered(@Query() query: UnansweredQueryDto) {
    return this.synonyms.unanswered(query.limit ?? 25);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateSynonymGroupDto) {
    return this.synonyms.create({
      terms: dto.terms,
      note: dto.note,
      actorId: user.id,
    });
  }

  @Post(':id/terms')
  addTerm(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AddSynonymTermDto,
  ) {
    return this.synonyms.addTerm(id, dto.term);
  }

  @Delete(':id/terms/:termId')
  removeTerm(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('termId', ParseUUIDPipe) termId: string,
  ) {
    return this.synonyms.removeTerm(id, termId);
  }

  /**
   * Deactivating is the reversible move — a group that turns out to be wrong
   * stops affecting search immediately without losing the words somebody
   * collected.
   */
  @Patch(':id/active')
  setActive(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetSynonymActiveDto,
  ) {
    return this.synonyms.setActive(id, dto.is_active);
  }

  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.synonyms.remove(id);
  }
}
