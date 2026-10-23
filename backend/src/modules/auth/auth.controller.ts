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
  Req,
} from '@nestjs/common';
import { Request } from 'express';
import { UserRole } from '@prisma/client';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import { AccountDeletionService } from './deletion/account-deletion.service';
import { DeleteAccountDto } from './dto/account-deletion.dto';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import {
  RegisterDeviceKeyDto,
  RenameDeviceKeyDto,
} from './dto/device-key.dto';
import { DeviceProof } from '../../common/guards/device-proof.guard';
import { RequireStepUp } from '../../common/decorators/require-step-up.decorator';
import { AssuranceLevel } from '@prisma/client';
import { RequestStepUpDto, VerifyStepUpDto } from './dto/step-up.dto';
import { TotpCodeDto } from './dto/recovery.dto';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import {
  RequestOtpDto,
  ResetPasswordDto,
  VerifyOtpDto,
} from './dto/otp.dto';
import {
  RenameDeviceDto,
  ReviewSellerVerificationDto,
  SecuritySettingsDto,
  SubmitSellerVerificationDto,
  UpdateAccountDto,
} from './dto/account.dto';
import {
  CompleteOtpLoginDto,
  CompleteReverseOtpLoginDto,
  ReverseOtpStatusDto,
  StartOtpLoginDto,
} from './dto/otp-login.dto';
import { SetPasswordDto } from './dto/password-credential.dto';
import {
  PhoneChangeCodeDto,
  StartPhoneChangeDto,
} from './dto/phone-change.dto';
import {
  RecoveryCaseStatusDto,
  SubmitRecoveryCaseDto,
} from './dto/account-recovery.dto';
import { requestContextFrom } from './interfaces/request-context.interface';

/**
 * Everything a woman can do to her own account.
 *
 * Almost every handler here takes `@CurrentUser().id` and hands it to a
 * service that reads or writes only that user's rows — her sessions, her
 * devices, her recovery codes, her phone change. That is a rule about the row
 * being touched, not one the guard can state, which is what `@SelfScoped` is
 * for. The one route that *is* declarative — reviewing somebody else's seller
 * application — carries its own `@Roles`/`@Authorize` and is judged by those.
 *
 * Without this the guard's fail-closed default refused `GET /auth/me`, and
 * because that is the call every cold start makes to restore a session, no
 * signed-in account could be restored on any client: the app opened, asked who
 * she was, was told 403, and dropped her back at the sign-in wall. The admin
 * console was unreachable for exactly that reason.
 */
@SelfScoped(
  "every handler acts on the caller's own account, scoped by the user id taken from her access token and never from the request body",
)
@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly deletion: AccountDeletionService,
  ) {}

  @Public()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('guest')
  @HttpCode(HttpStatus.CREATED)
  guest(@Req() req: Request) {
    return this.auth.guest(requestContextFrom(req));
  }

  @Public()
  @Throttle({ default: { limit: 8, ttl: 60_000 } })
  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  @DeviceProof()
  register(@Body() dto: RegisterDto, @Req() req: Request) {
    return this.auth.register(
      dto,
      requestContextFrom(req),
      (req as Request & { provenDevice?: { deviceKeyId: string } }).provenDevice
        ?.deviceKeyId,
    );
  }

  @Public()
  @Throttle({ default: { limit: 8, ttl: 60_000 } })
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @DeviceProof()
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.auth.login(
      dto,
      requestContextFrom(req),
      (req as Request & { provenDevice?: { deviceKeyId: string } }).provenDevice
        ?.deviceKeyId,
    );
  }

  @Public()
  /**
   * Rotation is where the device binding bites: a refresh token issued to a
   * device can only be exchanged by a caller who can sign with that device's
   * key, which turns an exfiltrated token into an inert string.
   */
  @DeviceProof()
  @Post('refresh-token')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() dto: RefreshTokenDto, @Req() req: Request) {
    return this.auth.refresh(
      dto.refresh_token,
      requestContextFrom(req),
      (req as Request & { provenDevice?: { deviceKeyId: string } }).provenDevice
        ?.deviceKeyId,
    );
  }

  @Public()
  @Post('logout')
  @HttpCode(HttpStatus.OK)
  logout(@Body() dto: RefreshTokenDto, @Req() req: Request) {
    return this.auth.logout(dto.refresh_token, requestContextFrom(req));
  }

  // Cutting every other session is the intruder's best move as much as the
  // owner's, so it sits at AAL3 alongside the money.
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'logout_others')
  @Post('logout-all')
  @HttpCode(HttpStatus.OK)
  logoutAll(@CurrentUser() user: AuthUser) {
    // Every *other* session. The one making the request just passed AAL3 —
    // it is the owner reacting to a compromise, and cutting her own session
    // too signed her out mid-flow behind a "done" message.
    return this.auth.logoutAll(user.id, user.sessionId);
  }

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  forgotPassword(@Body() dto: ForgotPasswordDto, @Req() req: Request) {
    return this.auth.forgotPassword(dto.phone, requestContextFrom(req));
  }

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('otp/request')
  @HttpCode(HttpStatus.OK)
  requestOtp(@Body() dto: RequestOtpDto, @Req() req: Request) {
    return this.auth.requestOtp(
      dto.phone,
      dto.purpose,
      requestContextFrom(req),
      dto.client_nonce,
    );
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('otp/verify')
  @HttpCode(HttpStatus.OK)
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.auth.verifyOtp(dto.phone, dto.purpose, dto.code);
  }

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto.phone, dto.code, dto.new_password);
  }

  // ───────────────────── OTP-first sign-in (the main door) ─────────────────

  /**
   * She types her number; we send a code.
   *
   * Answers identically for a number with an account and one without, which is
   * what stops this unauthenticated route being a public "is she on Reem"
   * lookup.
   */
  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('otp/login/start')
  @HttpCode(HttpStatus.OK)
  startOtpLogin(@Body() dto: StartOtpLoginDto, @Req() req: Request) {
    return this.auth.startOtpLogin(dto, requestContextFrom(req));
  }

  /**
   * The code. Either a session, or a ticket to create the account.
   *
   * Device proof is optional here for the same reason it is on `register`: a
   * client that has not enrolled a key yet must still be able to get in. Where
   * a key is presented, the session is bound to it.
   */
  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @DeviceProof()
  @Post('otp/login/verify')
  @HttpCode(HttpStatus.OK)
  completeOtpLogin(@Body() dto: CompleteOtpLoginDto, @Req() req: Request) {
    return this.auth.completeOtpLogin(
      dto,
      requestContextFrom(req),
      (req as Request & { provenDevice?: { deviceKeyId: string } }).provenDevice
        ?.deviceKeyId,
    );
  }

  /**
   * The reverse rail's step two: she has sent the message.
   *
   * Takes no code, because there is none to take — the proof is an inbound SMS
   * whose sender the provider checked. Throttled like the code route and
   * device-proof-aware for the same reasons.
   */
  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @DeviceProof()
  @Post('otp/login/reverse')
  @HttpCode(HttpStatus.OK)
  completeReverseOtpLogin(
    @Body() dto: CompleteReverseOtpLoginDto,
    @Req() req: Request,
  ) {
    return this.auth.completeReverseOtpLogin(
      dto,
      requestContextFrom(req),
      (req as Request & { provenDevice?: { deviceKeyId: string } }).provenDevice
        ?.deviceKeyId,
    );
  }

  /**
   * "Has my message arrived yet?" — polled while she is in her SMS app.
   *
   * A higher throttle than the routes that decide something, because this one
   * decides nothing: it reads a ceremony's state, spends no attempt, and
   * reveals only `pending` / `verified` / `expired` about a challenge the
   * caller already had to know the number and nonce of.
   */
  @Public()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('otp/reverse/status')
  @HttpCode(HttpStatus.OK)
  reverseOtpStatus(@Body() dto: ReverseOtpStatusDto) {
    return this.auth.reverseOtpStatus(dto);
  }

  // ───────────────────── The optional password credential ──────────────────

  /**
   * Opting into a password, or replacing one.
   *
   * AAL3, because a password added by whoever picked up an unlocked phone is a
   * back door that survives her locking the screen again.
   */
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'password_credential')
  @Post('account/password')
  @HttpCode(HttpStatus.OK)
  setPassword(
    @CurrentUser() user: AuthUser,
    @Body() dto: SetPasswordDto,
    @Req() req: Request,
  ) {
    return this.auth.setPassword(
      user.id,
      dto,
      requestContextFrom(req),
      user.sessionId,
    );
  }

  /** Dropping it again. Same rung: it is still a credential change. */
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'password_credential')
  @Delete('account/password')
  @HttpCode(HttpStatus.OK)
  removePassword(@CurrentUser('id') userId: string, @Req() req: Request) {
    return this.auth.removePassword(userId, requestContextFrom(req));
  }

  // ─────────────────────── Phone change (two-sided) ────────────────────────

  /**
   * Step one: a code to the number she is leaving.
   *
   * The outgoing number is challenged first on purpose — it is the half an
   * attacker holding a stolen session cannot answer, so the flow stops before
   * any code is sent to a number they control.
   */
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'phone_change')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('account/phone/start')
  @HttpCode(HttpStatus.OK)
  startPhoneChange(
    @CurrentUser() user: AuthUser,
    @Body() dto: StartPhoneChangeDto,
    @Req() req: Request,
  ) {
    return this.auth.startPhoneChange(
      user.id,
      dto.new_phone,
      requestContextFrom(req),
      user.sessionId,
      (req as Request & { provenDevice?: { deviceKeyId: string } }).provenDevice
        ?.deviceKeyId,
    );
  }

  /** Step two: that code, which then triggers one to the new number. */
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'phone_change')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('account/phone/:id/verify-current')
  @HttpCode(HttpStatus.OK)
  verifyCurrentPhone(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PhoneChangeCodeDto,
    @Req() req: Request,
  ) {
    return this.auth.verifyCurrentPhone(
      userId,
      id,
      dto.code,
      requestContextFrom(req),
    );
  }

  /** Step three: the code on the new number, and the account moves. */
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'phone_change')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('account/phone/:id/confirm')
  @HttpCode(HttpStatus.OK)
  confirmPhoneChange(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PhoneChangeCodeDto,
    @Req() req: Request,
  ) {
    return this.auth.confirmPhoneChange(
      user.id,
      id,
      dto.code,
      requestContextFrom(req),
      user.sessionId,
    );
  }

  @Get('account/phone/pending')
  pendingPhoneChange(@CurrentUser('id') userId: string) {
    return this.auth.pendingPhoneChange(userId);
  }

  /** Abandoning a change costs nothing and gives nothing away. No step-up. */
  @Delete('account/phone/:id')
  @HttpCode(HttpStatus.OK)
  cancelPhoneChange(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.auth.cancelPhoneChange(userId, id);
  }

  // ─────────────────── Support-mediated recovery (the last door) ───────────

  /**
   * Opens a case: the SIM is gone, and nothing self-service can reach her.
   *
   * Unauthenticated by necessity — she cannot sign in, that is the premise —
   * and therefore throttled hard and answered uniformly. Everything it asks for
   * is data the platform already holds; there is no field here for a selfie or
   * an identity document, by decision.
   */
  @Public()
  @Throttle({ default: { limit: 3, ttl: 3_600_000 } })
  @Post('recovery/cases')
  @HttpCode(HttpStatus.CREATED)
  submitRecoveryCase(
    @Body() dto: SubmitRecoveryCaseDto,
    @Req() req: Request,
  ) {
    return this.auth.submitRecoveryCase(dto, requestContextFrom(req));
  }

  /**
   * The claimant checking back.
   *
   * POST rather than GET with a query string: the claim secret must never end
   * up in a URL, where it would be written into every proxy log between her
   * handset and the server.
   */
  @Public()
  @Throttle({ default: { limit: 20, ttl: 3_600_000 } })
  @Post('recovery/cases/:id/status')
  @HttpCode(HttpStatus.OK)
  recoveryCaseStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RecoveryCaseStatusDto,
  ) {
    return this.auth.recoveryCaseStatus(id, dto.claim_secret);
  }

  /**
   * Cases open against this account, so the app can put a warning in front of
   * her while the cool-off is still running.
   */
  @Get('recovery/cases')
  openRecoveryCases(@CurrentUser('id') userId: string) {
    return this.auth.openRecoveryCases(userId);
  }

  /**
   * The owner killing a case.
   *
   * The single most important action in the recovery design, and deliberately
   * the cheapest: no step-up, no device proof. Anyone holding a live session
   * here is either her or an attacker who already has everything recovery could
   * give them — so friction would only ever stop the real owner.
   */
  @Post('recovery/cases/:id/cancel')
  @HttpCode(HttpStatus.OK)
  cancelRecoveryCase(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: Request,
  ) {
    return this.auth.cancelRecoveryCase(userId, id, requestContextFrom(req));
  }

  @Get('me')
  me(@CurrentUser('id') userId: string) {
    return this.auth.me(userId);
  }

  @Get('account')
  account(@CurrentUser() user: AuthUser) {
    return this.auth.account(user.id, user.sessionId);
  }

  /**
   * Whether she can delete the account right now, and what is in the way if
   * not. Asked before the step-up, so she is never made to enter a code only
   * to be told an order is still on its way.
   */
  @Get('account/deletion')
  accountDeletionStatus(@CurrentUser('id') userId: string) {
    return this.deletion.preflight(userId);
  }

  /**
   * Deletes her account. Irreversible, so it takes everything the platform
   * has: the request signed by her enrolled handset, a fresh second factor,
   * the new-device cooldown, and an explicit `confirm: true` in the body.
   * A POST rather than a DELETE because it carries a body.
   */
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'account_deletion')
  @Throttle({ default: { limit: 3, ttl: 60_000 } })
  @Post('account/delete')
  @HttpCode(HttpStatus.OK)
  deleteAccount(
    @CurrentUser('id') userId: string,
    @Body() dto: DeleteAccountDto,
    @Req() req: Request,
  ) {
    return this.deletion.deleteAccount(
      userId,
      dto.reason,
      requestContextFrom(req),
    );
  }

  // The phone number IS the account, so moving it is the most consequential
  // edit in the product — it redirects every future recovery code.
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'phone_change')
  @Patch('account')
  updateAccount(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateAccountDto,
  ) {
    return this.auth.updateAccount(userId, dto);
  }

  // `PATCH /auth/account/password` is gone. It did the same job as
  // `POST /auth/account/password` under a second name and a second set of
  // rules, which is how two endpoints drift: one revoked her other sessions
  // and one did not, and nothing said which the app should call. The POST is
  // the single door, and it keeps the revocation.

  @Patch('security')
  updateSecurity(
    @CurrentUser('id') userId: string,
    @Body() dto: SecuritySettingsDto,
  ) {
    return this.auth.updateSecuritySettings(userId, dto);
  }

  /**
   * Registers the device's public key and returns the `kid` every later proof
   * is signed under.
   *
   * Public and unauthenticated on purpose: a visitor's device exists before
   * her account does, and holding a key proves nothing on its own — it only
   * gives the platform a stable, unforgeable name for the handset.
   */
  @Public()
  @OptionalAuth()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('device-keys')
  @HttpCode(HttpStatus.CREATED)
  registerDeviceKey(
    @Body() dto: RegisterDeviceKeyDto,
    @Req() req: Request,
    @CurrentUser('id') userId?: string,
  ) {
    return this.auth.registerDeviceKey(dto, requestContextFrom(req), userId);
  }

  /**
   * Asks for a second factor before a sensitive action. Answers identically
   * whatever the account's state, and refuses outright while the device is
   * inside its new-device cooldown.
   */
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('step-up/request')
  @HttpCode(HttpStatus.OK)
  requestStepUp(
    @Body() dto: RequestStepUpDto,
    @CurrentUser() user: AuthUser,
    @Req() req: Request,
  ) {
    return this.auth.requestStepUp(
      user.id,
      user.sessionId,
      dto.scope,
      requestContextFrom(req),
    );
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('step-up/verify')
  @HttpCode(HttpStatus.OK)
  verifyStepUp(
    @Body() dto: VerifyStepUpDto,
    @CurrentUser() user: AuthUser,
    @Req() req: Request,
  ) {
    return this.auth.verifyStepUp(
      user.id,
      user.sessionId,
      dto.scope,
      dto.code,
      requestContextFrom(req),
      dto.method,
    );
  }

  /**
   * Recovery codes.
   *
   * Generating is AAL3 because a fresh set silently invalidates the old one:
   * an intruder who could regenerate would lock the owner out of her own
   * fallback while handing herself a new one.
   */
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'recovery_codes')
  @Post('recovery/codes')
  @HttpCode(HttpStatus.CREATED)
  generateRecoveryCodes(@CurrentUser('id') userId: string) {
    return this.auth.generateRecoveryCodes(userId);
  }

  /** Counts only — never reveals a code. */
  @Get('recovery/codes')
  recoveryCodeStatus(@CurrentUser('id') userId: string) {
    return this.auth.recoveryCodeStatus(userId);
  }

  /**
   * TOTP enrolment. Mandatory for the privileged roles, optional for everyone
   * else, and the only factor in the system with no network in its path.
   */
  @Post('totp/enroll')
  @HttpCode(HttpStatus.OK)
  enrollTotp(@CurrentUser() user: AuthUser) {
    return this.auth.enrollTotp(user.id);
  }

  @Post('totp/confirm')
  @HttpCode(HttpStatus.OK)
  confirmTotp(@CurrentUser('id') userId: string, @Body() dto: TotpCodeDto) {
    return this.auth.confirmTotp(userId, dto.code);
  }

  @Get('devices')
  devices(@CurrentUser('id') userId: string) {
    return this.auth.listDevices(userId);
  }

  @Patch('devices/:id')
  renameDevice(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RenameDeviceKeyDto,
  ) {
    return this.auth.renameDevice(userId, id, dto.label);
  }

  // `POST /auth/devices/:id/trust` is gone. It conferred trust on nothing more
  // than a live session and a device id, which made "trusted device" a claim
  // the client could simply assert. Trust is now earned by completing an OTP
  // challenge on the device, and by nothing else.

  /**
   * Revoking a device is one of the actions a compromised account holder
   * reaches for first, so it takes a device proof when the caller has a key —
   * an attacker with a stolen access token should not be able to cut off the
   * owner's own handset.
   */
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'device_revocation')
  @Delete('devices/:id')
  @HttpCode(HttpStatus.OK)
  revokeDevice(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.auth.revokeDevice(userId, id);
  }

  @Get('sessions')
  sessions(@CurrentUser('id') userId: string) {
    return this.auth.listSessions(userId);
  }

  @Delete('sessions/:id')
  @HttpCode(HttpStatus.OK)
  revokeSession(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.auth.revokeSession(userId, id);
  }

  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'seller_verification')
  @Post('seller-verification')
  @HttpCode(HttpStatus.OK)
  submitSellerVerification(
    @CurrentUser('id') userId: string,
    @Body() dto: SubmitSellerVerificationDto,
    @Req() req: Request,
  ) {
    return this.auth.submitSellerVerification(
      userId,
      dto,
      requestContextFrom(req),
    );
  }

  @Get('seller-verification/me')
  mySellerVerification(@CurrentUser('id') userId: string) {
    return this.auth.mySellerVerification(userId);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Authorize({
    action: 'review',
    resource: 'seller',
    permissions: [AppPermission.sellerVerificationReview],
  })
  @Patch('seller-verification/:id/review')
  reviewSellerVerification(
    @CurrentUser('id') reviewerId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReviewSellerVerificationDto,
  ) {
    return this.auth.reviewSellerVerification(reviewerId, id, dto);
  }
}
