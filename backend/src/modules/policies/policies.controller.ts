import {
  Body,
  Controller,
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
import { UserRole } from '@prisma/client';

import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { requestContextFrom } from '../auth/interfaces/request-context.interface';
import {
  AcceptPoliciesDto,
  PolicyLocaleQueryDto,
  PolicyRequiredQueryDto,
} from './dto/policy.dto';
import { PoliciesService, PolicyConsentSource } from './policies.service';

/**
 * The published policies — readable by anyone, with or without an account.
 *
 * The unauthenticated reads are the whole design, not an oversight. A woman
 * deciding whether to sign up has to be able to read what she would be
 * agreeing to, the registration form has to name the documents before there is
 * a session to authorise the question with, and a link to the returns policy
 * sent to a customer over WhatsApp has to open. A policy behind a login is not
 * a published policy.
 *
 * Nothing here leaks anything account-specific to an anonymous caller: the
 * "you accepted this on …" line only appears when the request carries a
 * session, which `@OptionalAuth()` is what makes possible on an open route.
 */
@Controller('policies')
export class PoliciesController {
  constructor(private readonly policies: PoliciesService) {}

  /**
   * Every published policy. The policy centre's list.
   *
   * `@OptionalAuth()` rather than `@Public()`: both skip the session
   * requirement, but only the first resolves `req.user` when a token *is*
   * present — which is what lets each card say "you accepted this on …"
   * without a second round trip, and what would silently never appear under a
   * bare `@Public()`.
   */
  @OptionalAuth()
  @Get()
  catalogue(
    @Query() query: PolicyLocaleQueryDto,
    @CurrentUser() user?: AuthUser,
  ) {
    return this.policies.catalogue(query.locale, user?.id);
  }

  /**
   * What a new account of this kind must sign.
   *
   * Before `:slug`, because GoRouter is not the only greedy matcher in this
   * stack: `required`, `pending` and `acceptances` are literal segments and
   * would otherwise be read as policy slugs.
   */
  @Public()
  @Get('required')
  required(@Query() query: PolicyRequiredQueryDto) {
    return this.policies.requiredForRole(
      query.role ?? UserRole.CUSTOMER,
      query.locale,
    );
  }

  /**
   * What this account still owes a signature on. Empty for almost everyone,
   * almost always — the app calls it on launch and shows the gate only when it
   * comes back non-empty.
   */
  @SelfScoped('scoped to the calling account: every query is keyed by its own user id')
  @Get('pending')
  pending(@CurrentUser() user: AuthUser, @Query() query: PolicyLocaleQueryDto) {
    return this.policies.pending(user.id, user.role, query.locale);
  }

  /** Her receipts: which policy, which version, which day. */
  @SelfScoped('scoped to the calling account: every query is keyed by its own user id')
  @Get('acceptances')
  acceptances(
    @CurrentUser() user: AuthUser,
    @Query() query: PolicyLocaleQueryDto,
  ) {
    return this.policies.acceptances(user.id, query.locale);
  }

  /**
   * Sign. Idempotent — the same version twice is one row and one answer.
   *
   * Answers with what is still outstanding rather than with the rows written,
   * so the consent gate can close itself on the response instead of asking
   * again.
   */
  @SelfScoped('scoped to the calling account: every query is keyed by its own user id')
  @Post('accept')
  @HttpCode(HttpStatus.OK)
  async accept(
    @CurrentUser() user: AuthUser,
    @Body() dto: AcceptPoliciesDto,
    @Req() req: Request,
  ) {
    const context = requestContextFrom(req);
    const recorded = await this.policies.record(
      user.id,
      dto.version_ids,
      PolicyConsentSource.Reconsent,
      {
        locale: dto.locale,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
      },
    );

    return {
      recorded,
      pending: await this.policies.pending(user.id, user.role, dto.locale),
    };
  }

  /**
   * One issue by id, including an archived one.
   *
   * This is what makes an acceptance auditable from the app: her receipt names
   * a version, and this returns the text of that version rather than of
   * whatever is published today.
   */
  @Public()
  @Get('versions/:id')
  version(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() query: PolicyLocaleQueryDto,
  ) {
    return this.policies.version(id, query.locale);
  }

  /** One policy, with its body and its version history. */
  @OptionalAuth()
  @Get(':slug')
  document(
    @Param('slug') slug: string,
    @Query() query: PolicyLocaleQueryDto,
    @CurrentUser() user?: AuthUser,
  ) {
    return this.policies.document(slug, query.locale, user?.id);
  }
}
