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
  Query,
  Req,
} from '@nestjs/common';
import { Request } from 'express';
import { AssuranceLevel, UserRole } from '@prisma/client';
import { Authorize } from '../../../common/decorators/authorize.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../../../common/decorators/current-user.decorator';
import { AppPermission } from '../../../common/permissions';
import { RequireStepUp } from '../../../common/decorators/require-step-up.decorator';
import { DeviceProof } from '../../../common/guards/device-proof.guard';
import { AccountRecoveryService } from '../recovery/account-recovery.service';
import { SecurityForensicsService } from './security-forensics.service';
import {
  RecoveryCaseQueryDto,
  RejectRecoveryCaseDto,
  ReviewRecoveryCaseDto,
} from '../dto/account-recovery.dto';
import {
  SecurityEventQueryDto,
  UserTimelineQueryDto,
} from '../dto/security-forensics.dto';
import { requestContextFrom } from '../interfaces/request-context.interface';

/**
 * The staff view of authentication.
 *
 * Two jobs that only look similar. **Forensics** is read-only and answers "what
 * happened to this account" — the question support is asked every time a woman
 * says she has been locked out or that someone else is in her account, and
 * which previously had no answer short of a psql prompt. **Recovery review** is
 * the one place staff can act on an account they do not own, and every control
 * on it exists because that is a dangerous thing to be able to do.
 *
 * Both are deliberately narrow. Forensics returns events, not content: who
 * signed in, from what device, when a factor was consumed. It does not return
 * her orders, her chats or her address book, because the support tool that can
 * read those is the support tool that leaks them.
 */
@Roles(
  UserRole.SUPER_ADMIN,
  UserRole.ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.SUPPORT_ADMIN,
  UserRole.SUPPORT,
)
@Controller('admin/security')
export class SecurityAdminController {
  constructor(
    private readonly forensics: SecurityForensicsService,
    private readonly recovery: AccountRecoveryService,
  ) {}

  // ───────────────────────────── Forensics ─────────────────────────────

  @Authorize({
    action: 'read',
    resource: 'audit',
    permissions: [AppPermission.securityForensicsRead],
  })
  @Get('events')
  events(@Query() query: SecurityEventQueryDto) {
    return this.forensics.events(query);
  }

  @Authorize({
    action: 'read',
    resource: 'audit',
    permissions: [AppPermission.securityForensicsRead],
  })
  @Get('login-attempts')
  loginAttempts(@Query() query: SecurityEventQueryDto) {
    return this.forensics.loginAttempts(query);
  }

  /**
   * Everything the platform knows about how one account has been accessed,
   * merged into a single ordered story.
   *
   * Merged rather than four separate lists on purpose: an investigator reading
   * "code requested, code delivered by SMS, sign-in from a new device, all
   * other sessions revoked, payout details changed" in sequence sees a takeover.
   * The same rows in four tables read as noise.
   */
  @Authorize({
    action: 'read',
    resource: 'audit',
    permissions: [AppPermission.securityForensicsRead],
  })
  @Get('users/:id/timeline')
  timeline(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() query: UserTimelineQueryDto,
  ) {
    return this.forensics.timeline(id, query);
  }

  @Authorize({
    action: 'read',
    resource: 'session',
    permissions: [AppPermission.sessionManage],
  })
  @Get('users/:id/sessions')
  sessions(@Param('id', ParseUUIDPipe) id: string) {
    return this.forensics.sessionsAndDevices(id);
  }

  /**
   * Cutting every session on an account staff do not own.
   *
   * The one *write* in the forensic half, and it is here because the support
   * call that starts "someone else is in my account" needs an answer in the
   * next thirty seconds, not after a password reset she cannot complete. It
   * only ever removes access — it never grants any — which is why it needs a
   * reason and an audit line rather than dual control.
   */
  @Authorize({
    action: 'delete',
    resource: 'session',
    permissions: [AppPermission.sessionManage],
  })
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'admin_session_revocation')
  @Delete('users/:id/sessions')
  @HttpCode(HttpStatus.OK)
  revokeSessions(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectRecoveryCaseDto,
    @CurrentUser() actor: AuthUser,
    @Req() req: Request,
  ) {
    return this.forensics.revokeAllSessions(
      id,
      actor.id,
      dto.reason,
      requestContextFrom(req),
    );
  }

  // ────────────────────────── Recovery review ──────────────────────────

  @Authorize({
    action: 'read',
    resource: 'account',
    permissions: [AppPermission.accountRecoveryReview],
  })
  @Get('recovery-cases')
  recoveryCases(@Query() query: RecoveryCaseQueryDto) {
    return this.recovery.list(query);
  }

  @Authorize({
    action: 'read',
    resource: 'account',
    permissions: [AppPermission.accountRecoveryReview],
  })
  @Get('recovery-cases/:id')
  recoveryCase(@Param('id', ParseUUIDPipe) id: string) {
    return this.recovery.detail(id);
  }

  /**
   * One half of the dual control.
   *
   * Step-up on top of the permission, and the reason is the threat model this
   * whole path was designed against: the attacker who does not phish a shopper
   * but a support agent. A stolen staff session must not be able to click
   * approve, and a single staff account — stolen or not — must not be able to
   * complete a case alone. `AccountRecoveryService.approve` enforces the second
   * half by refusing an approver who has already approved this case.
   */
  @Authorize({
    action: 'update',
    resource: 'account',
    permissions: [AppPermission.accountRecoveryReview],
  })
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'account_recovery_review')
  @Post('recovery-cases/:id/approve')
  @HttpCode(HttpStatus.OK)
  approveRecoveryCase(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReviewRecoveryCaseDto,
    @CurrentUser() actor: AuthUser,
    @Req() req: Request,
  ) {
    return this.recovery.approve(
      id,
      actor.id,
      dto.note,
      requestContextFrom(req),
    );
  }

  /** Refusing costs nothing and gives nothing away, so it takes no step-up. */
  @Authorize({
    action: 'update',
    resource: 'account',
    permissions: [AppPermission.accountRecoveryReview],
  })
  @Post('recovery-cases/:id/reject')
  @HttpCode(HttpStatus.OK)
  rejectRecoveryCase(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectRecoveryCaseDto,
    @CurrentUser() actor: AuthUser,
    @Req() req: Request,
  ) {
    return this.recovery.reject(
      id,
      actor.id,
      dto.reason,
      requestContextFrom(req),
    );
  }
}
