import {
  Body,
  ConflictException,
  Controller,
  ForbiddenException,
  HttpCode,
  HttpException,
  HttpStatus,
  Logger,
  Post,
  Req,
  Res,
} from '@nestjs/common';
import { SkipThrottle, Throttle } from '@nestjs/throttler';
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { Request, Response } from 'express';
import { AuthUser, CurrentUser } from '../../../../backend/src/common/decorators/current-user.decorator';
import { Public } from '../../../../backend/src/common/decorators/public.decorator';
import { SelfScoped } from '../../../../backend/src/common/decorators/self-scoped.decorator';
import { DeviceProof } from '../../../../backend/src/common/guards/device-proof.guard';
import { AuthService } from '../../../../backend/src/modules/auth/auth.service';
import { CompleteOtpLoginDto, DeviceDescriptorDto } from '../../../../backend/src/modules/auth/dto/otp-login.dto';
import { requestContextFrom } from '../../../../backend/src/modules/auth/interfaces/request-context.interface';
import { PrismaService } from '../../../../backend/src/prisma/prisma.service';
import { IdentityLinkRepository } from './identity-link.repository';
import { SendSmsHookService } from './send-sms-hook.service';
import { SupabaseAuthClient, SupabaseIdentity } from './supabase-auth.client';
import { mintLoginProof } from './supabase-login-proof';

export class SupabaseExchangeDto extends DeviceDescriptorDto {
  @IsString()
  @MinLength(16)
  @MaxLength(4096)
  access_token!: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  client_nonce?: string;
}

export class SupabaseLinkDto {
  @IsString()
  @MinLength(16)
  @MaxLength(4096)
  access_token!: string;
}

/**
 * Sign-in through Supabase Auth, session through the Reem API.
 *
 * Supabase Auth owns the one-time code: the app calls `signInWithOtp` and
 * `verifyOtp` against it directly, and the code is delivered by the Send SMS
 * hook below. What Supabase cannot know is who that number is on this
 * platform — a customer, a seller with a suspended shop, a staff member who
 * must still pass TOTP — so the app then trades its fresh Supabase session
 * here for the platform's own, device-bound session, issued by the backend's
 * unmodified sign-in path.
 *
 * The result is one identity in two places, joined by
 * `reem_supabase.identity_links`: the Reem session authorises every API call,
 * and the Supabase session authorises the two things the app reaches directly
 * — Realtime channels and (in future) Storage — under Row Level Security.
 */
@Controller('auth/supabase')
export class SupabaseIdentityController {
  private readonly logger = new Logger(SupabaseIdentityController.name);

  constructor(
    private readonly auth: AuthService,
    private readonly supabase: SupabaseAuthClient,
    private readonly links: IdentityLinkRepository,
    private readonly prisma: PrismaService,
    private readonly smsHook: SendSmsHookService,
  ) {}

  /**
   * A confirmed Supabase session in, the same answer `POST /auth/otp/login/verify`
   * gives out: a Reem session, or a registration ticket for a new number.
   */
  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @DeviceProof()
  @Post('exchange')
  @HttpCode(HttpStatus.OK)
  async exchange(@Body() dto: SupabaseExchangeDto, @Req() req: Request) {
    const identity = await this.supabase.identify(dto.access_token);
    const owner = await this.prisma.user.findUnique({
      where: { phone: identity.phone },
      select: { id: true },
    });
    await this.retireStaleLink(identity, owner?.id ?? null);

    const loginDto = Object.assign(new CompleteOtpLoginDto(), {
      phone: identity.phone,
      code: mintLoginProof(identity.phone),
      client_nonce: dto.client_nonce,
      device_name: dto.device_name,
      platform: dto.platform,
      app_version: dto.app_version,
      device_fingerprint: dto.device_fingerprint,
    });
    const provenDeviceKeyId = (req as Request & { provenDevice?: { deviceKeyId: string } }).provenDevice
      ?.deviceKeyId;

    const result = await this.auth.completeOtpLogin(loginDto, requestContextFrom(req), provenDeviceKeyId);

    if (owner) await this.links.link(identity.authUserId, owner.id);
    return result;
  }

  /**
   * Binds the caller's Supabase session to the Reem account she is signed in
   * to. Called after registration — the account did not exist at exchange
   * time — and after a phone change, which it carries across to Supabase.
   */
  @SelfScoped('binds only the caller: the Reem user comes from her access token, the auth user from her own Supabase session')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('link')
  @HttpCode(HttpStatus.OK)
  async link(@Body() dto: SupabaseLinkDto, @CurrentUser() user: AuthUser) {
    const identity = await this.supabase.identify(dto.access_token);
    const account = await this.prisma.user.findUnique({
      where: { id: user.id },
      select: { id: true, phone: true },
    });
    if (!account?.phone) throw new ForbiddenException('Account has no phone number');

    const existing = await this.links.findByAuthUser(identity.authUserId);
    if (existing && existing.userId !== account.id) {
      await this.retire(identity.authUserId);
      throw new ConflictException({
        code: 'SUPABASE_IDENTITY_RESET',
        message: 'This sign-in belonged to another account. Sign in again.',
      });
    }

    if (identity.phone !== account.phone) {
      // Only an identity already bound to this account may follow it to a new
      // number. An unbound session with a different phone proves nothing.
      if (!existing) {
        throw new ForbiddenException({
          code: 'SUPABASE_PHONE_MISMATCH',
          message: 'The Supabase session is for a different phone number',
        });
      }
      await this.supabase.updatePhone(identity.authUserId, account.phone);
    }

    await this.links.link(identity.authUserId, account.id);
    return { linked: true };
  }

  /**
   * The Send SMS hook for Supabase Auth.
   *
   * Supabase generates the code; this delivers it through the backend's own
   * transport chain — WhatsApp Cloud, the local SMS aggregator, voice — in the
   * priority order `otp_transport_routes` holds, so a route an operator turned
   * off in the admin console is off here too. Signed with the hook secret
   * (Standard Webhooks); anything unsigned is refused before it is parsed.
   */
  @Public()
  @SkipThrottle()
  @Post('send-sms-hook')
  @HttpCode(HttpStatus.OK)
  async sendSms(@Req() req: Request & { rawBody?: Buffer }, @Res() res: Response) {
    // Answered directly rather than through the global exception filter:
    // Supabase reads its own error envelope, `{ error: { http_code, message } }`.
    try {
      res.status(HttpStatus.OK).json(await this.smsHook.handle(req));
    } catch (error) {
      if (error instanceof HttpException) {
        res.status(error.getStatus()).json(error.getResponse());
        return;
      }
      this.logger.error(`Send SMS hook failed: ${String(error)}`);
      res
        .status(HttpStatus.INTERNAL_SERVER_ERROR)
        .json({ error: { http_code: 500, message: 'Could not send the sign-in code' } });
    }
  }

  private async retireStaleLink(identity: SupabaseIdentity, ownerId: string | null) {
    const existing = await this.links.findByAuthUser(identity.authUserId);
    if (!existing || existing.userId === ownerId) return;

    // The number this auth user holds now belongs to someone else, or to no
    // one: the account it was bound to moved to another number. Whoever holds
    // an old Supabase session for it must not keep reaching that account's
    // Realtime channels, so the auth user goes, taking its sessions with it.
    await this.retire(identity.authUserId);
    throw new ConflictException({
      code: 'SUPABASE_IDENTITY_RESET',
      message: 'This number was re-assigned. Sign in again.',
    });
  }

  private async retire(authUserId: string) {
    await this.links.unlinkAuthUser(authUserId);
    try {
      await this.supabase.deleteUser(authUserId);
    } catch (error) {
      this.logger.error(`Could not retire auth user ${authUserId}: ${String(error)}`);
    }
  }
}
