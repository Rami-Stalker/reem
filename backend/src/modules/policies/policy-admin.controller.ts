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
import { UserRole } from '@prisma/client';

import { Authorize } from '../../common/decorators/authorize.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AppPermission } from '../../common/permissions';
import {
  CreatePolicyVersionDto,
  PublishPolicyVersionDto,
  UpdatePolicyDocumentDto,
  UpdatePolicyVersionDto,
} from './dto/policy-admin.dto';
import { PolicyAdminService } from './policy-admin.service';

/**
 * The console's policy desk — the whole point of the subsystem.
 *
 * The client asked to be able to change the terms without updating the app,
 * and these six routes are that: edit a draft, publish it, and every phone in
 * the country shows the new text on its next read. Nothing here ships in a
 * release.
 *
 * Behind `policy:manage`, which only SUPER_ADMIN and OPERATIONS_ADMIN hold.
 * Deliberately not `content:manage`: that one is held by every seller on the
 * platform, and publishing a version of the terms of use is not a content
 * moderation action — it changes the contract between Ohara and every account.
 *
 * Every write here is recorded by `AdminAuditInterceptor` — who, which route,
 * which document, and whether it succeeded — without this file asking.
 */
@Roles(
  UserRole.SUPER_ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.ADMIN,
  UserRole.SUPPORT,
  UserRole.SUPPORT_ADMIN,
  UserRole.FINANCE_ADMIN,
  UserRole.CONTENT_MODERATOR,
)
@Authorize({
  action: 'manage',
  resource: 'policy',
  permissions: [AppPermission.policyManage],
})
@Controller('admin/policies')
export class PolicyAdminController {
  constructor(private readonly policies: PolicyAdminService) {}

  /** Every document, every version, every translation. */
  @Get()
  documents() {
    return this.policies.documents();
  }

  /** How far a published version has landed across the population. */
  @Get('consent-summary')
  consentSummary() {
    return this.policies.consentSummary();
  }

  /** The document's settings — audience, order, whether it must be signed. */
  @Patch(':id')
  updateDocument(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdatePolicyDocumentDto,
  ) {
    return this.policies.updateDocument(id, dto);
  }

  /** Open a draft, cloned from what is published unless text is supplied. */
  @Post(':id/versions')
  @HttpCode(HttpStatus.CREATED)
  createVersion(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreatePolicyVersionDto,
    @CurrentUser('id') actorId: string,
  ) {
    return this.policies.createVersion(id, dto, actorId);
  }

  /** Edit the open draft. Refuses anything already published. */
  @Patch('versions/:versionId')
  updateVersion(
    @Param('versionId', ParseUUIDPipe) versionId: string,
    @Body() dto: UpdatePolicyVersionDto,
  ) {
    return this.policies.updateVersion(versionId, dto);
  }

  /**
   * Publish. The one route on this controller with a blast radius: with
   * `requires_reacceptance` it asks every account on that side of the
   * marketplace to sign again before it can carry on.
   */
  @Post('versions/:versionId/publish')
  @HttpCode(HttpStatus.OK)
  publishVersion(
    @Param('versionId', ParseUUIDPipe) versionId: string,
    @Body() dto: PublishPolicyVersionDto,
    @CurrentUser('id') actorId: string,
  ) {
    return this.policies.publishVersion(versionId, dto, actorId);
  }

  /** Throw away the open draft. Drafts only — see `PolicyAdminService`. */
  @Delete('versions/:versionId')
  @HttpCode(HttpStatus.OK)
  discardVersion(@Param('versionId', ParseUUIDPipe) versionId: string) {
    return this.policies.discardVersion(versionId);
  }
}
