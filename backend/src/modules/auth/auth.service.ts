import { randomInt } from 'crypto';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import {
  AuditSeverity,
  NotificationType,
  OtpPurpose,
  Prisma,
  SellerVerification,
  SellerVerificationStatus,
  SellerLevel,
  StepUpMethod,
  SessionStatus,
  SecurityEventType,
  User,
  UserRole,
  RiskLevel,
} from '@prisma/client';
import { serializeUser } from '../../common/serializers';
import { AuthRepository } from './auth.repository';
import { PasswordService } from './password.service';
import { TokenPair, TokenService } from './token.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RequestContext } from './interfaces/request-context.interface';
import { OtpService } from './otp.service';
import { DeviceService } from './device.service';
import { DeviceRegistryService } from './device/device-registry.service';
import { StepUpService } from './step-up/step-up.service';
import { RecoveryService } from './recovery/recovery.service';
import { TotpService } from './totp/totp.service';
import { RegisterDeviceKeyDto } from './dto/device-key.dto';
import { PrismaService } from '../../prisma/prisma.service';
import { MediaService } from '../media/media.service';
import { AuditService } from './audit.service';
import { GuestService } from './guest.service';
import {
  ReviewSellerVerificationDto,
  SecuritySettingsDto,
  SubmitSellerVerificationDto,
  UpdateAccountDto,
} from './dto/account.dto';
import { SubmitRecoveryCaseDto } from './dto/account-recovery.dto';
import {
  CompleteOtpLoginDto,
  StartOtpLoginDto,
} from './dto/otp-login.dto';
import { SetPasswordDto } from './dto/password-credential.dto';
import { RegistrationTicketService } from './login/registration-ticket.service';
import { PhoneChangeService } from './phone-change/phone-change.service';
import { AccountRecoveryService } from './recovery/account-recovery.service';
import { maskDestination } from './otp/otp-transport';
import { resolvePermissions } from '../../common/authorization/permission-resolver';
import {
  PoliciesService,
  PolicyConsentSource,
} from '../policies/policies.service';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly users: AuthRepository,
    private readonly passwords: PasswordService,
    private readonly tokens: TokenService,
    private readonly otp: OtpService,
    private readonly devices: DeviceService,
    private readonly deviceKeys: DeviceRegistryService,
    private readonly stepUp: StepUpService,
    private readonly recovery: RecoveryService,
    private readonly totp: TotpService,
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly guests: GuestService,
    private readonly registrationTickets: RegistrationTicketService,
    private readonly phoneChanges: PhoneChangeService,
    private readonly accountRecovery: AccountRecoveryService,
    private readonly media: MediaService,
    private readonly policies: PoliciesService,
  ) {}

  /**
   * Creates the account, for a number whose control has already been proved.
   *
   * The ordering is the point and it is the reverse of what was here before.
   * Registration used to mint an account for any number anybody typed, with
   * verification arriving later or never — so one person could sit down and
   * claim every number in a contact list, permanently locking women who had
   * never heard of Reem out of signing up under their own number. Now the code
   * comes first (`POST /auth/otp/login`), and this endpoint will only accept a
   * `registration_ticket` issued off the back of it.
   *
   * The password is optional, and the default is not to have one.
   */
  async register(
    dto: RegisterDto,
    context: RequestContext,
    provenDeviceKeyId?: string,
  ) {
    const role = dto.role ?? UserRole.CUSTOMER;
    if (role !== UserRole.CUSTOMER && role !== UserRole.SELLER) {
      throw new ForbiddenException('Cannot self-register as a privileged role');
    }

    const ticket = await this.registrationTickets.verify(
      dto.registration_ticket,
    );
    if (!ticket || ticket.phone !== dto.phone) {
      throw this.authException(
        HttpStatus.FORBIDDEN,
        'PHONE_VERIFICATION_REQUIRED',
        'Verify the number before creating an account',
      );
    }

    if (dto.password !== undefined) this.assertStrongPassword(dto.password);

    // Before the account exists, not after. A refusal here costs her a tap;
    // the same refusal after `users.create` would leave an orphan account for
    // a number that can then never be registered again.
    const consentVersionIds = await this.requiredPolicyConsent(
      role,
      dto.accepted_policy_version_ids,
    );

    const name = this.displayNameFor(dto);

    // Already canonical E.164 — RegisterDto normalises at the boundary.
    const phone = dto.phone;
    if (await this.users.findByPhone(phone)) {
      throw new ConflictException('Phone number is already registered');
    }

    const passwordHash = dto.password
      ? await this.passwords.hash(dto.password)
      : null;
    const username = await this.generateUsername(name);

    const user = await this.users.create({
      name,
      phone,
      username,
      passwordHash,
      passwordSetAt: passwordHash ? new Date() : null,
      // The ticket is the proof. Marking it here rather than leaving it for a
      // later "verify your number" step is what stops an account existing in
      // an unverified limbo that `assertLoginEligibility` then refuses.
      phoneVerifiedAt: new Date(),
      isVerified: true,
      role,
      // Q43/Q138 P1 — recorded as an attestation the account made, with the
      // moment it was made, rather than a column that silently defaulted true.
      declaredFemale: true,
      declaredFemaleAt: new Date(),
      location: `${dto.city.trim()}, ${dto.country.trim()}`,
      imageUrl: `https://i.pravatar.cc/150?u=${encodeURIComponent(phone)}`,
    });

    // The signature, written against the account it belongs to.
    //
    // Not inside a transaction with `users.create`, and that is a considered
    // trade rather than an oversight: the account is created through a
    // repository that owns its own client, and the failure mode of writing the
    // consent a moment late is one this system already handles — an account
    // with no acceptance on file is exactly what `PoliciesService.pending`
    // treats as outstanding, so she meets the consent gate on her next launch
    // and signs there. The reverse ordering has no such recovery.
    await this.policies.record(
      user.id,
      consentVersionIds,
      PolicyConsentSource.Registration,
      {
        locale: dto.preferred_language,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
      },
    );

    const device = await this.devices.resolveDevice(user.id, context);
    const deviceKeyId = await this.bindDeviceKey(provenDeviceKeyId, user.id);
    // She completed a code on this handset seconds ago, which is the only way
    // a device becomes trusted. The 24h cooldown still applies — trusted is
    // not the same as old.
    if (deviceKeyId) await this.deviceKeys.markVerified(deviceKeyId);
    const tokens = await this.tokens.issueTokens(user, {
      deviceId: device.id,
      deviceKeyId,
      context,
    });
    await this.audit.record({
      actorId: user.id,
      action: 'register',
      category: 'auth',
      outcome: 'success',
      context,
      metadata: { password_enabled: passwordHash !== null },
    });
    const guestMigration = await this.guests.migrateToUser(
      context.guestToken,
      user.id,
      context,
    );

    return {
      ...(await this.authResponse(user, tokens)),
      guest_migration: guestMigration,
      verification: {
        phone_verified: true,
        seller_application_required: role === UserRole.SELLER,
      },
    };
  }

  /**
   * Phone + password sign-in — the *optional* path, not the main one.
   *
   * Owner decision 1: a password is off by default and, when she has one, it
   * can never admit a device the account has not signed in from before. That
   * property is enforced below, and it is what makes offering a password at
   * all defensible: the credential most likely to be reused from another
   * breached site, guessed, or shoulder-surfed cannot on its own move the
   * account onto an attacker's handset. It only shortens the journey on a
   * handset that already completed a code.
   *
   * The order of checks matters and used to leak: an unauthenticated caller
   * could distinguish "no such number" from "wrong password" from "suspended"
   * from "seller pending approval" — before proving anything at all. On a
   * women-only platform in Syria that is not an abstract enumeration concern:
   * it confirms to anyone who asks whether a specific woman has an account
   * here, and what state it is in.
   *
   * So nothing about the account is disclosed until the password verifies.
   * Every pre-credential failure returns the same `INVALID_CREDENTIALS`, and
   * the real reason is recorded server-side where an investigator can see it.
   * The account-state answers (suspended, locked, phone unverified) are given
   * only after the password is known to be correct — at which point the caller
   * is the account holder and is entitled to know why she cannot get in.
   */
  async login(
    dto: LoginDto,
    context: RequestContext,
    provenDeviceKeyId?: string,
  ) {
    const identifier = dto.phone;
    const user = await this.users.findByPhone(identifier);

    if (!user || !user.passwordHash) {
      await this.recordLoginAttempt(
        user?.id ?? null,
        identifier,
        false,
        user ? 'password_login_not_enabled' : 'account_not_found',
        context,
      );
      throw this.invalidCredentials();
    }

    // A locked account must not become a password oracle either: the answer is
    // identical whether or not the attacker guessed right.
    if (user.lockedUntil && user.lockedUntil > new Date()) {
      await this.recordLoginAttempt(user.id, identifier, false, 'locked', context);
      throw this.authException(
        HttpStatus.TOO_MANY_REQUESTS,
        'TOO_MANY_ATTEMPTS',
        'Too many attempts',
      );
    }

    const valid = await this.passwords.verify(dto.password, user.passwordHash);
    if (!valid) {
      await this.handleFailedLogin(user, identifier, context);
      throw this.invalidCredentials();
    }

    if (user.disabledAt) {
      await this.recordLoginAttempt(user.id, identifier, false, 'disabled', context);
      throw this.authException(
        HttpStatus.FORBIDDEN,
        'ACCOUNT_SUSPENDED',
        'Account suspended',
      );
    }

    await this.assertLoginEligibility(user, identifier, context);

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        failedLoginCount: 0,
        lockedUntil: null,
        lastLoginAt: new Date(),
        ...(this.passwords.needsRehash(user.passwordHash) && {
          passwordHash: await this.passwords.hash(dto.password),
        }),
      },
    });

    // ── The gate that makes an optional password safe ──────────────────
    //
    // A correct password on a handset this account has never used is not a
    // sign-in; it is a request for one. It falls through to the same OTP the
    // passwordless path uses, so the outcome for an attacker holding leaked
    // credentials is identical to holding nothing at all.
    if (!(await this.isEnrolledDevice(user.id, provenDeviceKeyId))) {
      return this.refuseNewDeviceWithChallenge(user, context);
    }

    const device = await this.devices.resolveDevice(user.id, {
      ...context,
      deviceName: dto.device_name ?? context.deviceName,
      platform: dto.platform ?? context.platform,
      appVersion: dto.app_version ?? context.appVersion,
      fingerprint: dto.device_fingerprint ?? context.fingerprint,
    });
    const deviceKeyId = await this.bindDeviceKey(provenDeviceKeyId, user.id);
    const tokens = await this.tokens.issueTokens(user, {
      deviceId: device.id,
      deviceKeyId,
      context,
    });
    await this.recordLoginAttempt(user.id, identifier, true, null, context);
    await this.announceIfNewDevice(user.id, deviceKeyId, device.name);
    const guestMigration = await this.guests.migrateToUser(
      context.guestToken,
      user.id,
      context,
    );

    return {
      ...(await this.authResponse(user, tokens)),
      guest_migration: guestMigration,
      device_verification_required:
        user.deviceVerificationRequired && !device.verifiedAt,
    };
  }

  // Social sign-in was removed deliberately, not misplaced.
  //
  // Identity on Reem is phone-only by locked requirement, so Google/Apple gave
  // the platform a second identity namespace the product does not have — and
  // the code that resolved it produced an unauthenticated account-takeover:
  // with no `id_token` present the verifier trusted the raw request body,
  // fabricated an identity from it, and `socialSignIn` then matched an
  // existing account by the attacker-supplied email. It also skipped every
  // gate `login()` enforces. Repairing it would have meant keeping a
  // hand-rolled RS256/JWKS verifier alive for a feature the requirements rule
  // out, so the route, the service, the DTO and the client integration are all
  // gone.

  // ───────────────────── OTP-first sign-in (the main door) ─────────────────

  /**
   * Step one: she types her number, we send a code.
   *
   * The response is byte-identical whether or not the number has an account —
   * same shape, same masked destination, same expiry. That uniformity is the
   * whole security property of this endpoint. It is unauthenticated by
   * necessity, and any difference in the answer turns it into a public lookup
   * for "is this woman on Reem", which on this platform is a question with
   * consequences well beyond the account.
   *
   * A number with no account still gets a real code: that is how signup starts,
   * and it is also why the two cases cannot be told apart from outside.
   */
  async startOtpLogin(dto: StartOtpLoginDto, context: RequestContext) {
    const user = await this.users.findByPhone(dto.phone);

    // A suspended account is told nothing here. The refusal comes at
    // verification, where the caller has already proved she holds the number
    // and is entitled to know why she cannot get in.
    const challenge = await this.otp.request({
      phone: dto.phone,
      purpose: OtpPurpose.LOGIN,
      channel: dto.channel,
      userId: user?.id,
      clientNonce: dto.client_nonce,
      context,
    });

    return { ...challenge, next: 'verify_code' };
  }

  /**
   * Step two: the code.
   *
   * Two outcomes, and which one she gets is the first moment the platform says
   * anything about whether the number is known. Either a session, or a ticket
   * to create the account the number does not yet have.
   */
  async completeOtpLogin(
    dto: CompleteOtpLoginDto,
    context: RequestContext,
    provenDeviceKeyId?: string,
  ) {
    // Consuming the code is what proves possession of the SIM. `consume`
    // rather than `verify` because the phone-verified stamp belongs to an
    // account, and there may not be one yet.
    await this.otp.consume(
      dto.phone,
      OtpPurpose.LOGIN,
      dto.code,
      dto.client_nonce,
    );

    const user = await this.users.findByPhone(dto.phone);

    if (!user) {
      const ticket = await this.registrationTickets.issue({
        phone: dto.phone,
        otp_request_id: '',
      });
      return {
        status: 'registration_required',
        phone: dto.phone,
        ...ticket,
      };
    }

    if (user.disabledAt) {
      await this.recordLoginAttempt(
        user.id,
        dto.phone,
        false,
        'disabled',
        context,
      );
      throw this.authException(
        HttpStatus.FORBIDDEN,
        'ACCOUNT_SUSPENDED',
        'Account suspended',
      );
    }

    const device = await this.devices.resolveDevice(user.id, {
      ...context,
      deviceName: dto.device_name ?? context.deviceName,
      platform: dto.platform ?? context.platform,
      appVersion: dto.app_version ?? context.appVersion,
      fingerprint: dto.device_fingerprint ?? context.fingerprint,
    });
    const deviceKeyId = await this.bindDeviceKey(provenDeviceKeyId, user.id);
    // Completing a challenge on this handset is the entire path to a trusted
    // device. There is no endpoint that simply declares one.
    if (deviceKeyId) await this.deviceKeys.markVerified(deviceKeyId);

    const refreshed = await this.prisma.user.update({
      where: { id: user.id },
      data: {
        failedLoginCount: 0,
        lockedUntil: null,
        lastLoginAt: new Date(),
        // She just proved control of the number, whatever the account thought
        // beforehand. This is also the repair path for a row whose
        // verification predates the column existing at all.
        phoneVerifiedAt: user.phoneVerifiedAt ?? new Date(),
        isVerified: true,
      },
    });

    const tokens = await this.tokens.issueTokens(refreshed, {
      deviceId: device.id,
      deviceKeyId,
      context,
    });
    await this.recordLoginAttempt(refreshed.id, dto.phone, true, null, context);
    await this.announceIfNewDevice(refreshed.id, deviceKeyId, device.name);
    const guestMigration = await this.guests.migrateToUser(
      context.guestToken,
      refreshed.id,
      context,
    );

    return {
      status: 'authenticated',
      ...(await this.authResponse(refreshed, tokens)),
      guest_migration: guestMigration,
      password_enabled: refreshed.passwordSetAt !== null,
    };
  }

  // ───────────────────── The optional password credential ──────────────────

  /**
   * Turns a password on, or replaces one.
   *
   * AAL3 at the route, so this cannot be done by whoever picked up an unlocked
   * phone. Enabling it does not weaken the account, because of the new-device
   * gate in `login()` — but it does create a credential that can be reused
   * from a breached site, so it is an explicit, elevated, auditable choice
   * rather than a default.
   */
  async setPassword(
    userId: string,
    dto: SetPasswordDto,
    context: RequestContext,
    sessionId?: string,
  ) {
    this.assertStrongPassword(dto.new_password);
    const user = await this.requireUser(userId);

    if (user.passwordHash) {
      if (!dto.current_password) {
        throw new BadRequestException({
          code: 'CURRENT_PASSWORD_REQUIRED',
          message: 'Current password is required',
        });
      }
      const valid = await this.passwords.verify(
        dto.current_password,
        user.passwordHash,
      );
      if (!valid) throw new UnauthorizedException('Current password is invalid');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash: await this.passwords.hash(dto.new_password),
        passwordSetAt: new Date(),
      },
    });

    // Replacing a password is what somebody does when she thinks another
    // person has been in her account, so it cuts every other session. Setting
    // one for the first time is not that, and signing her out of her other
    // devices for opting into a convenience would be a punishment.
    if (user.passwordHash) {
      await this.tokens.revokeAll(userId, sessionId);
    }

    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        type: SecurityEventType.PASSWORD_ENABLED,
        riskLevel: RiskLevel.MEDIUM,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        metadata: { replaced: user.passwordHash !== null },
      },
    });
    await this.audit.record({
      actorId: userId,
      action: user.passwordHash ? 'password_replaced' : 'password_enabled',
      category: 'account',
      outcome: 'success',
      severity: AuditSeverity.WARNING,
      context,
    });

    return {
      password_enabled: true,
      other_sessions_revoked: user.passwordHash !== null,
    };
  }

  /**
   * Turns it off again.
   *
   * Not merely a settings toggle: removing the password removes an attack
   * surface, and she must be able to do that without help. Sessions are left
   * alone deliberately — dropping a credential she is not using should not
   * sign her out of her own phone.
   */
  async removePassword(userId: string, context: RequestContext) {
    const user = await this.requireUser(userId);
    if (!user.passwordHash) {
      return { password_enabled: false };
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: null, passwordSetAt: null },
    });
    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        type: SecurityEventType.PASSWORD_DISABLED,
        riskLevel: RiskLevel.LOW,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
      },
    });
    await this.audit.record({
      actorId: userId,
      action: 'password_disabled',
      category: 'account',
      outcome: 'success',
      severity: AuditSeverity.WARNING,
      context,
    });

    return { password_enabled: false };
  }

  /**
   * Is this handset one the account has actually signed in from before?
   *
   * Three conditions, and dropping any one of them reopens the hole. The key
   * must be *this* account's — a key registered by the attacker is still a
   * valid key. It must not be revoked — otherwise revoking a stolen device
   * achieves nothing. And it must carry `verifiedAt`, which is set only by
   * completing a code on the device itself; without that, an attacker simply
   * registers a fresh key alongside the stolen password and walks in.
   */
  private async isEnrolledDevice(
    userId: string,
    provenDeviceKeyId: string | undefined,
  ): Promise<boolean> {
    if (!provenDeviceKeyId) return false;
    const key = await this.prisma.deviceKey.findFirst({
      where: {
        id: provenDeviceKeyId,
        userId,
        revokedAt: null,
        verifiedAt: { not: null },
      },
      select: { id: true },
    });
    return key !== null;
  }

  /**
   * The password was right, the handset is new: fall through to a code.
   *
   * A challenge is issued and returned rather than a bare refusal, so the app
   * can go straight to the code screen — the journey is "password, then code",
   * not "password, then error, then start again". The refusal is a 403 with the
   * challenge in `details`, which keeps the HTTP semantics honest: this request
   * did not authenticate anyone.
   */
  private async refuseNewDeviceWithChallenge(
    user: User,
    context: RequestContext,
  ): Promise<never> {
    await this.recordLoginAttempt(
      user.id,
      user.phone ?? '',
      false,
      'password_on_unenrolled_device',
      context,
      AuditSeverity.WARNING,
    );
    await this.prisma.securityEvent.create({
      data: {
        actorId: user.id,
        type: SecurityEventType.PASSWORD_NEW_DEVICE_BLOCKED,
        riskLevel: RiskLevel.HIGH,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
      },
    });

    let challenge: Record<string, unknown> | null = null;
    try {
      challenge = await this.otp.request({
        phone: user.phone as string,
        purpose: OtpPurpose.LOGIN,
        userId: user.id,
        context,
      });
    } catch (error) {
      // She may already be at her hourly code limit. That is not a reason to
      // turn a 403 into a 500 — the refusal stands either way, and the app
      // falls back to its own resend timer.
      this.logger.warn(
        `Could not issue a fallback code for ${maskDestination(user.phone ?? '')}: ${
          error instanceof Error ? error.message : 'unknown error'
        }`,
      );
    }

    throw new HttpException(
      {
        code: 'DEVICE_VERIFICATION_REQUIRED',
        message:
          'هذا الجهاز جديد على حسابكِ. أرسلنا رمزًا إلى رقمكِ لإكمال تسجيل الدخول.',
        ...(challenge && { challenge }),
      },
      HttpStatus.FORBIDDEN,
    );
  }

  // ─────────────────────── Phone change (two-sided) ────────────────────────

  startPhoneChange(
    userId: string,
    newPhone: string,
    context: RequestContext,
    sessionId?: string,
    deviceKeyId?: string,
  ) {
    return this.phoneChanges.start(
      userId,
      newPhone,
      context,
      sessionId,
      deviceKeyId,
    );
  }

  verifyCurrentPhone(
    userId: string,
    requestId: string,
    code: string,
    context: RequestContext,
  ) {
    return this.phoneChanges.verifyCurrent(userId, requestId, code, context);
  }

  confirmPhoneChange(
    userId: string,
    requestId: string,
    code: string,
    context: RequestContext,
    keepSessionId?: string,
  ) {
    return this.phoneChanges.confirm(
      userId,
      requestId,
      code,
      context,
      keepSessionId,
    );
  }

  cancelPhoneChange(userId: string, requestId: string) {
    return this.phoneChanges.cancel(userId, requestId);
  }

  pendingPhoneChange(userId: string) {
    return this.phoneChanges.pending(userId);
  }

  // ──────────────────── Support-mediated recovery (owner) ──────────────────

  submitRecoveryCase(dto: SubmitRecoveryCaseDto, context: RequestContext) {
    return this.accountRecovery.submit(dto, context);
  }

  recoveryCaseStatus(caseId: string, claimSecret: string) {
    return this.accountRecovery.claimantStatus(caseId, claimSecret);
  }

  cancelRecoveryCase(userId: string, caseId: string, context: RequestContext) {
    return this.accountRecovery.cancelByOwner(userId, caseId, context);
  }

  openRecoveryCases(userId: string) {
    return this.accountRecovery.openCasesFor(userId);
  }

  requestStepUp(
    userId: string,
    sessionId: string | undefined,
    scope: string,
    context: RequestContext,
  ) {
    return this.stepUp.request(userId, sessionId, scope, context);
  }

  verifyStepUp(
    userId: string,
    sessionId: string | undefined,
    scope: string,
    code: string,
    context: RequestContext,
    method?: StepUpMethod,
  ) {
    return this.stepUp.verify(userId, sessionId, scope, code, context, method);
  }

  generateRecoveryCodes(userId: string) {
    return this.recovery.generate(userId);
  }

  recoveryCodeStatus(userId: string) {
    return this.recovery.status(userId);
  }

  async enrollTotp(userId: string) {
    const user = await this.requireUser(userId);
    return this.totp.enroll(userId, user.phone ?? user.username);
  }

  confirmTotp(userId: string, code: string) {
    return this.totp.confirm(userId, code);
  }

  async guest(context: RequestContext) {
    return this.guests.issue(context);
  }

  async refresh(
    refreshToken: string,
    context: RequestContext,
    provenDeviceKeyId?: string,
  ) {
    const { user, tokens } = await this.tokens.rotate(
      refreshToken,
      context,
      provenDeviceKeyId,
    );
    return this.authResponse(user, tokens);
  }

  async logout(refreshToken: string, context: RequestContext) {
    await this.tokens.revoke(refreshToken);
    await this.audit.record({
      action: 'logout',
      category: 'auth',
      outcome: 'success',
      context,
    });
    return { message: 'Logged out successfully' };
  }

  async logoutAll(userId: string, keepSessionId?: string) {
    await this.tokens.revokeAll(userId, keepSessionId);
    await this.audit.record({
      actorId: userId,
      action: 'logout_all',
      category: 'auth',
      outcome: 'success',
    });
    return { message: 'All other sessions were revoked' };
  }

  /**
   * Who is signed in, and what they are allowed to do.
   *
   * The permission set ships with the identity because the console has to draw
   * itself before it can call anything. Without it the admin shell showed every
   * staff role the same twelve destinations and let a support agent walk into
   * the finance screen to collect a 403 — a menu that lies about what the
   * person can do, which is worse than a shorter menu.
   *
   * This is presentation only. The server still decides on every request; the
   * client is being told what to *offer*, never what to *permit*.
   */
  async me(userId: string) {
    const user = await this.requireUser(userId);
    const permissions = await resolvePermissions(
      this.prisma,
      user.id,
      user.role,
    );
    return {
      user: { ...serializeUser(user), is_courier: await this.isCourier(user.id) },
      permissions: [...permissions].sort(),
    };
  }

  /**
   * The response is a fixed sentence and nothing else.
   *
   * It used to spread the OTP result into the body — which, before the code
   * was removed from that result, meant the "If that number is registered…"
   * privacy message shipped with the reset code attached to it. Even without
   * the code, returning `otp_request_id` for a number that exists and nothing
   * for one that does not turns this route back into an enumeration oracle.
   */
  async forgotPassword(phone: string, context: RequestContext) {
    await this.otp.request({
      phone,
      purpose: OtpPurpose.PASSWORD_RESET,
      context,
    });
    await this.audit.record({
      action: 'password_reset_requested',
      category: 'auth',
      outcome: 'success',
      severity: AuditSeverity.WARNING,
      context,
    });
    return {
      message: 'If that number is registered, a reset code has been sent.',
    };
  }

  requestOtp(
    phone: string,
    purpose: OtpPurpose,
    context: RequestContext,
    clientNonce?: string,
  ) {
    return this.otp.request({ phone, purpose, context, clientNonce });
  }

  verifyOtp(phone: string, purpose: OtpPurpose, code: string) {
    return this.otp.verify(phone, purpose, code);
  }

  async resetPassword(
    phone: string,
    code: string,
    newPassword: string,
    context?: RequestContext,
  ) {
    this.assertStrongPassword(newPassword);
    await this.otp.verify(phone, OtpPurpose.PASSWORD_RESET, code);
    const user = await this.users.findByPhone(phone);
    if (user) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: {
          passwordHash: await this.passwords.hash(newPassword),
          failedLoginCount: 0,
          lockedUntil: null,
        },
      });
      await this.tokens.revokeAll(user.id);

      // The highest-value account-takeover path in the product wrote no
      // telemetry at all: an investigator could see the login that followed a
      // reset but never the reset itself.
      await this.audit.record({
        actorId: user.id,
        action: 'password_reset_completed',
        category: 'auth',
        outcome: 'success',
        severity: AuditSeverity.CRITICAL,
        context,
      });
      await this.prisma.securityEvent.create({
        data: {
          actorId: user.id,
          type: SecurityEventType.PASSWORD_CHANGED,
          riskLevel: RiskLevel.HIGH,
          ipAddress: context?.ipAddress,
          userAgent: context?.userAgent,
          metadata: { via: 'password_reset' },
        },
      });
    }
    return { message: 'Password was reset successfully' };
  }

  /**
   * Everything the security centre needs, in one call.
   *
   * It used to answer two booleans, which meant the app could not tell her
   * whether she had a password, whether she had any recovery codes left, or —
   * the one that matters most — that somebody had opened a request to move her
   * account to another number and it completes on Thursday. A security screen
   * that cannot show the open threat is decoration.
   */
  async account(userId: string, sessionId?: string) {
    const user = await this.requireUser(userId);
    const [
      sellerVerification,
      permissions,
      recoveryCodes,
      totp,
      openRecoveryCases,
      session,
    ] = await Promise.all([
      this.prisma.sellerVerification.findUnique({ where: { userId } }),
      this.tokens.permissionsFor(user.id, user.role),
      this.recovery.status(userId),
      this.prisma.totpCredential.findUnique({
        where: { userId },
        select: { confirmedAt: true },
      }),
      this.accountRecovery.openCasesFor(userId),
      sessionId
        ? this.prisma.session.findFirst({
            where: { id: sessionId, userId },
            select: { newDeviceCooldownUntil: true, assuranceLevel: true },
          })
        : null,
    ]);

    const cooldown = session?.newDeviceCooldownUntil;

    return {
      user: serializeUser(user),
      permissions,
      security: {
        mfa_enabled: user.mfaEnabled,
        device_verification_required: user.deviceVerificationRequired,
        password_enabled: user.passwordSetAt !== null,
        totp_enabled: totp?.confirmedAt != null,
        totp_required: user.totpRequired,
        recovery_codes_remaining: recoveryCodes.remaining,
        payout_frozen_until: user.payoutFrozenUntil?.toISOString() ?? null,
        // The 24h SIM-swap delay, so the app can say when the locked actions
        // come back instead of refusing them with no explanation.
        new_device_cooldown_until:
          cooldown && cooldown > new Date() ? cooldown.toISOString() : null,
      },
      open_recovery_cases: openRecoveryCases,
      seller_verification: sellerVerification
        ? this.serializeSellerVerification(sellerVerification)
        : null,
    };
  }

  async updateAccount(userId: string, dto: UpdateAccountDto) {
    const data: Prisma.UserUpdateInput = {};
    if (dto.name !== undefined) data.name = dto.name.trim();
    if (dto.location !== undefined) data.location = dto.location.trim();
    if (dto.email !== undefined) {
      // Contact detail, not an identity: it is still unique so a seller cannot
      // squat another's business address, but nothing authenticates with it.
      const email = dto.email.trim().toLowerCase();
      const existing = await this.prisma.user.findUnique({ where: { email } });
      if (existing && existing.id !== userId) {
        throw new ConflictException('Email is already in use');
      }
      data.email = email;
    }
    // The phone number is deliberately NOT editable here any more.
    //
    // It used to be, behind a single code sent to the *incoming* number — which
    // is precisely the proof a SIM swapper has and the account's real owner may
    // not. Moving the number is a transfer of the account, not a profile edit,
    // so it lives in its own two-sided flow under `/auth/account/phone/*`
    // where control of the outgoing number is proved first.

    const user = await this.prisma.user.update({ where: { id: userId }, data });
    await this.audit.record({
      actorId: userId,
      action: 'update_account',
      category: 'account',
      outcome: 'success',
    });
    return { user: serializeUser(user) };
  }

  // `changePassword` lived here. It duplicated `setPassword` under a second
  // name — same job, slightly different rules — so it is gone and its
  // session-revocation behaviour moved into `setPassword` above.

  async updateSecuritySettings(userId: string, dto: SecuritySettingsDto) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: {
        ...(dto.mfa_enabled !== undefined && { mfaEnabled: dto.mfa_enabled }),
        ...(dto.device_verification_required !== undefined && {
          deviceVerificationRequired: dto.device_verification_required,
        }),
      },
    });
    return {
      mfa_enabled: user.mfaEnabled,
      device_verification_required: user.deviceVerificationRequired,
    };
  }

  registerDeviceKey(
    dto: RegisterDeviceKeyDto,
    context: RequestContext,
    userId?: string,
  ) {
    return this.deviceKeys
      .register(dto, context, userId)
      .then((key) => ({
        device_key_id: key.id,
        trust_level: key.trustLevel.toLowerCase(),
        hardware_backed: key.hardwareBacked,
      }));
  }

  listDevices(userId: string) {
    return this.deviceKeys.list(userId);
  }

  /**
   * Attaches the proven device to the account and, on a first sign-in from it,
   * leaves it untrusted. Trust arrives only when an OTP challenge is completed
   * on the device — see `DeviceRegistryService.markVerified`.
   */
  /**
   * A sign-in from a device the account has not used before is the single
   * signal most worth surfacing, and the moment at which "sign out everywhere"
   * is worth one tap. Silence here is what lets an intruder settle in.
   */
  private async announceIfNewDevice(
    userId: string,
    deviceKeyId: string | undefined,
    deviceLabel: string,
  ): Promise<void> {
    if (!deviceKeyId) return;
    const session = await this.prisma.session.findFirst({
      where: { userId, deviceKeyId },
      orderBy: { createdAt: 'desc' },
      select: { id: true, newDeviceCooldownUntil: true },
    });
    if (!session?.newDeviceCooldownUntil) return;
    await this.stepUp.announceNewDevice(userId, session.id, deviceLabel);
  }

  private async bindDeviceKey(
    provenDeviceKeyId: string | undefined,
    userId: string,
  ): Promise<string | undefined> {
    if (!provenDeviceKeyId) return undefined;
    const key = await this.deviceKeys.attachToUser(provenDeviceKeyId, userId);
    return key.id;
  }

  renameDevice(userId: string, deviceKeyId: string, label: string) {
    return this.deviceKeys.rename(userId, deviceKeyId, label);
  }



  revokeDevice(userId: string, deviceKeyId: string) {
    return this.deviceKeys.revoke(userId, deviceKeyId);
  }

  listSessions(userId: string) {
    return this.tokens.listSessions(userId);
  }

  revokeSession(userId: string, sessionId: string) {
    return this.tokens.revokeSession(userId, sessionId);
  }

  async submitSellerVerification(
    userId: string,
    dto: SubmitSellerVerificationDto,
    context?: RequestContext,
  ) {
    await this.assertUniqueSellerIdentifiers(userId, dto);

    // This route is where a customer becomes a seller — it sets
    // `role: SELLER` further down. So it is also the only honest moment to ask
    // her to sign the seller terms and the commission she is about to be
    // charged: at registration she was a shopper and those documents did not
    // address her, and after approval she is already selling.
    const consentVersionIds = await this.requiredPolicyConsent(
      UserRole.SELLER,
      dto.accepted_policy_version_ids,
    );

    const verification = await this.prisma.sellerVerification.upsert({
      where: { userId },
      update: {
        status: SellerVerificationStatus.PENDING,
        businessName: dto.business_name.trim(),
        legalName: dto.legal_name.trim(),
        businessCategory: dto.business_category.trim(),
        storeDescription: dto.store_description.trim(),
        storeLogoUrl: dto.store_logo_url.trim(),
        contactPhone: dto.contact_phone.trim(),
        contactEmail: dto.contact_email.trim().toLowerCase(),
        businessAddress: dto.business_address.trim(),
        warehouseAddress: dto.warehouse_address.trim(),
        commercialRegistration: dto.commercial_registration.trim(),
        governmentIdUrl: dto.government_id_url.trim(),
        businessLicenseUrl: dto.business_license_url.trim(),
        taxId: dto.tax_id?.trim(),
        bankName: dto.bank_name.trim(),
        accountHolder: dto.account_holder.trim(),
        iban: dto.iban.trim(),
        paymentInformation: this.json(dto.payment_information ?? {}),
        shippingMethods: this.json(dto.shipping_methods),
        returnPolicy: dto.return_policy.trim(),
        productCategories: this.json(dto.product_categories),
        yearsExperience: dto.years_experience,
        website: dto.website?.trim(),
        socialMediaLinks: this.json(dto.social_media_links ?? {}),
        documentUrls: dto.document_urls,
        rejectionReason: null,
        reviewReason: null,
        reviewedAt: null,
        reviewedBy: null,
        submittedAt: new Date(),
      },
      create: {
        userId,
        status: SellerVerificationStatus.PENDING,
        businessName: dto.business_name.trim(),
        legalName: dto.legal_name.trim(),
        businessCategory: dto.business_category.trim(),
        storeDescription: dto.store_description.trim(),
        storeLogoUrl: dto.store_logo_url.trim(),
        contactPhone: dto.contact_phone.trim(),
        contactEmail: dto.contact_email.trim().toLowerCase(),
        businessAddress: dto.business_address.trim(),
        warehouseAddress: dto.warehouse_address.trim(),
        commercialRegistration: dto.commercial_registration.trim(),
        governmentIdUrl: dto.government_id_url.trim(),
        businessLicenseUrl: dto.business_license_url.trim(),
        taxId: dto.tax_id?.trim(),
        bankName: dto.bank_name.trim(),
        accountHolder: dto.account_holder.trim(),
        iban: dto.iban.trim(),
        paymentInformation: this.json(dto.payment_information ?? {}),
        shippingMethods: this.json(dto.shipping_methods),
        returnPolicy: dto.return_policy.trim(),
        productCategories: this.json(dto.product_categories),
        yearsExperience: dto.years_experience,
        website: dto.website?.trim(),
        socialMediaLinks: this.json(dto.social_media_links ?? {}),
        documentUrls: dto.document_urls,
      },
    });
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        role: UserRole.SELLER,
        sellerVerifiedAt: null,
        sellerLevel: SellerLevel.BASIC,
      },
    });
    await this.policies.record(
      userId,
      consentVersionIds,
      PolicyConsentSource.SellerApplication,
      {
        ipAddress: context?.ipAddress,
        userAgent: context?.userAgent,
      },
    );
    await this.prisma.sellerVerificationStatusHistory.create({
      data: {
        verificationId: verification.id,
        status: SellerVerificationStatus.PENDING,
        reason: 'Application submitted',
      },
    });
    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        type: SecurityEventType.SELLER_VERIFICATION_SUBMITTED,
        riskLevel: RiskLevel.LOW,
      },
    });

    // Her documents are now part of a submitted application and must survive
    // the orphan sweep. The identity papers among them are PRIVATE assets: the
    // URLs recorded above are authorised endpoints, not files on the public
    // mount, and only she and a verification reviewer can resolve them.
    await this.media.markAttached(userId, [
      dto.store_logo_url,
      dto.government_id_url,
      dto.business_license_url,
      ...(Array.isArray(dto.document_urls)
        ? dto.document_urls.map((entry) =>
            typeof entry === 'string' ? entry : null,
          )
        : []),
    ]);

    return this.serializeSellerVerification(verification);
  }

  async mySellerVerification(userId: string) {
    const verification = await this.prisma.sellerVerification.findUnique({
      where: { userId },
    });
    return {
      seller_verification: verification
        ? this.serializeSellerVerification(verification)
        : null,
    };
  }

  /**
   * An approved seller's page opens to everyone.
   *
   * A storefront nobody may look at is not a storefront — the migration that
   * introduced private pages opened every seller that existed then, but a
   * seller approved afterwards kept the customer default, and every post she
   * published was hidden from shoppers' feeds and from the pages it was added
   * to. Her content and reshares carry denormalised copies of the flag, so
   * they move in the same transaction (see `UsersService.setProfileVisibility`).
   * A seller who had already opened her page keeps the date she did it.
   */
  private async openStorefront(userId: string) {
    await this.prisma.$transaction([
      this.prisma.user.updateMany({
        where: { id: userId, profileIsPublic: false },
        data: { profileIsPublic: true, profilePublicSince: new Date() },
      }),
      this.prisma.commerceContent.updateMany({
        where: { authorId: userId, authorIsPublic: false },
        data: { authorIsPublic: true },
      }),
      this.prisma.commerceContentReshare.updateMany({
        where: { resharerId: userId, resharerIsPublic: false },
        data: { resharerIsPublic: true },
      }),
    ]);
  }

  async reviewSellerVerification(
    reviewerId: string,
    verificationId: string,
    dto: ReviewSellerVerificationDto,
  ) {
    const status = dto.status as SellerVerificationStatus;
    const reason = (dto.reason ?? dto.rejection_reason)?.trim();
    if (!reason) {
      throw new BadRequestException({
        code: 'REVIEW_REASON_REQUIRED',
        message: 'A reason is required for every seller review action',
      });
    }
    const verification = await this.prisma.sellerVerification.update({
      where: { id: verificationId },
      data: {
        status,
        rejectionReason:
          status === SellerVerificationStatus.REJECTED
            ? dto.rejection_reason ?? reason
            : null,
        reviewReason: reason,
        reviewedBy: reviewerId,
        reviewedAt: new Date(),
        ...(status === SellerVerificationStatus.APPROVED && {
          user: {
            update: {
              role: UserRole.SELLER,
              sellerLevel: SellerLevel.VERIFIED,
              sellerVerifiedAt: new Date(),
            },
          },
        }),
        ...(status !== SellerVerificationStatus.APPROVED && {
          user: {
            update: {
              sellerLevel: SellerLevel.BASIC,
              sellerVerifiedAt: null,
            },
          },
        }),
      },
    });
    if (status === SellerVerificationStatus.APPROVED) {
      await this.openStorefront(verification.userId);
    }
    await this.prisma.sellerVerificationStatusHistory.create({
      data: {
        verificationId: verification.id,
        status,
        reason,
        adminId: reviewerId,
      },
    });
    await this.notifySellerReviewDecision(
      verification.userId,
      status,
      reason,
      verification.id,
    );
    await this.audit.record({
      actorId: reviewerId,
      action: 'review_seller_verification',
      category: 'seller_verification',
      outcome: status.toLowerCase(),
      severity:
        status === SellerVerificationStatus.SUSPENDED
          ? AuditSeverity.CRITICAL
          : AuditSeverity.WARNING,
      metadata: {
        verification_id: verification.id,
        reviewed_user_id: verification.userId,
        status,
        reason,
      },
    });
    await this.prisma.securityEvent.create({
      data: {
        actorId: reviewerId,
        type: SecurityEventType.SELLER_VERIFICATION_REVIEWED,
        riskLevel: RiskLevel.MEDIUM,
        metadata: {
          verification_id: verification.id,
          reviewed_user_id: verification.userId,
          status,
        },
      },
    });
    return this.serializeSellerVerification(verification);
  }

  /**
   * The body every entry point that mints a session returns.
   *
   * Permissions ship with the session, not only from `/auth/me`. The console
   * draws its navigation from this set, and when only `/auth/me` carried it an
   * administrator who had just signed in got a shell with an empty sidebar —
   * every destination filtered out — until something happened to refetch her.
   * A client should never hold a signed-in user whose permissions it does not
   * also hold.
   *
   * This is still presentation: the server resolves permissions again, from
   * the database, on every request it judges.
   */
  private async authResponse(user: User, tokens: TokenPair) {
    const [permissions, isCourier] = await Promise.all([
      resolvePermissions(this.prisma, user.id, user.role),
      this.isCourier(user.id),
    ]);
    return {
      user: { ...serializeUser(user), is_courier: isCourier },
      permissions: [...permissions].sort(),
      tokens,
    };
  }

  /**
   * Whether this account carries parcels.
   *
   * There is no COURIER value in `UserRole` — a rider is an ordinary account
   * with a `Courier` row attached, which is what the shipment routes check.
   * That makes the fact invisible to a client reading only the role, so the
   * app had no way to offer a courier her own round: the only door to it sat
   * in the seller menu. It is said here rather than inferred, and it is
   * presentation like the permission list beside it — the server still resolves
   * the courier on every call it judges.
   */
  private async isCourier(userId: string): Promise<boolean> {
    const courier = await this.prisma.courier.findUnique({
      where: { userId },
      select: { isActive: true },
    });
    return courier?.isActive === true;
  }

  /**
   * Checks that run only AFTER the password has verified.
   *
   * The seller-verification block used to live here, which produced the worst
   * usability defect in the product: a customer who tapped the "seller" chip
   * at registration was locked out of her own account permanently, with no
   * recovery path, because her role said SELLER and her application was still
   * pending. Approval status governs what a seller may *do*, not whether she
   * may hold a session — so it moved to the seller routes, where an unapproved
   * seller now signs in normally and sees her application status instead of a
   * login wall.
   */
  private async assertLoginEligibility(
    user: User,
    identifier: string,
    context: RequestContext,
  ) {
    if (user.phone && !user.phoneVerifiedAt && !user.isVerified) {
      await this.recordLoginAttempt(
        user.id,
        identifier,
        false,
        'phone_not_verified',
        context,
      );
      throw this.authException(
        HttpStatus.FORBIDDEN,
        'PHONE_NOT_VERIFIED',
        'Phone not verified',
      );
    }
  }

  /**
   * The single answer given for every pre-credential failure, so the response
   * carries no information about whether the number exists or what state the
   * account is in.
   */
  private invalidCredentials(): HttpException {
    return this.authException(
      HttpStatus.UNAUTHORIZED,
      'INVALID_CREDENTIALS',
      'Invalid credentials',
    );
  }

  private displayNameFor(dto: RegisterDto): string {
    const composed = [dto.first_name, dto.last_name]
      .map((part) => part?.trim())
      .filter((part): part is string => !!part)
      .join(' ');
    const name = composed || dto.name?.trim();
    if (!name || name.length < 2) {
      throw new BadRequestException({
        code: 'VALIDATION_ERROR',
        message: 'First name and last name are required',
      });
    }
    return name;
  }

  private authException(
    status: HttpStatus,
    code: string,
    message: string,
  ): HttpException {
    return new HttpException({ code, message }, status);
  }

  /**
   * The policy gate, shared by registration and the seller application.
   *
   * Returns the version ids to write a signature against, having checked that
   * every document this side of the marketplace must sign was among the ones
   * the client actually displayed. The check is against **version ids**, not
   * document ids: a client that cached the signup screen last month and posts
   * last month's version id has not shown her the terms she is agreeing to,
   * and it is told so by name so it can fetch and redisplay them.
   *
   * It fails *open* in two cases, both deliberate.
   *
   * **No published policies at all** — see `PoliciesService.requiredVersionIds`.
   * A platform nobody can register for is a worse failure than an hour of
   * accounts that signed nothing.
   *
   * **The field is absent entirely**, which is what an app build older than
   * this feature sends. The API deploys before a new app can reach every
   * handset — a store rollout takes days — so refusing those requests would
   * mean nobody on the shipped build could create an account until she
   * updated. An old client is not *withholding* consent; it does not know the
   * question exists. It is recorded as unsigned and meets the consent gate on
   * its next launch, which is precisely the case that gate was built for.
   *
   * An empty array is **not** the same thing: a client that sends the field
   * has been asked, and an answer that covers nothing is refused. That is the
   * whole distinction — `undefined` is "did not know", `[]` is "said no".
   */
  private async requiredPolicyConsent(
    role: UserRole,
    provided: string[] | undefined,
  ): Promise<string[]> {
    if (provided === undefined) return [];

    const required = await this.policies.requiredVersionIds(role);
    if (required.length === 0) return [];

    const supplied = new Set(provided);
    const missing = required.filter((item) => !supplied.has(item.versionId));
    if (missing.length > 0) {
      throw new HttpException(
        {
          code: 'POLICY_CONSENT_REQUIRED',
          message: 'The current version of every required policy must be accepted',
          policies: missing.map((item) => ({
            slug: item.slug,
            version_id: item.versionId,
          })),
        },
        HttpStatus.UNPROCESSABLE_ENTITY,
      );
    }

    return required.map((item) => item.versionId);
  }

  private async assertUniqueSellerIdentifiers(
    userId: string,
    dto: SubmitSellerVerificationDto,
  ) {
    const commercialRegistration = dto.commercial_registration.trim();
    const taxId = dto.tax_id?.trim();
    const duplicate = await this.prisma.sellerVerification.findFirst({
      where: {
        userId: { not: userId },
        OR: [
          { commercialRegistration },
          ...(taxId ? [{ taxId }] : []),
        ],
      },
      select: {
        commercialRegistration: true,
        taxId: true,
      },
    });
    if (!duplicate) return;

    if (duplicate.commercialRegistration === commercialRegistration) {
      throw new ConflictException({
        code: 'BUSINESS_REGISTRATION_ALREADY_EXISTS',
        message: 'Business registration number is already registered',
      });
    }
    throw new ConflictException({
      code: 'TAX_NUMBER_ALREADY_EXISTS',
      message: 'Tax number is already registered',
    });
  }

  private async notifySellerReviewDecision(
    userId: string,
    status: SellerVerificationStatus,
    reason: string,
    verificationId: string,
  ) {
    const title = this.sellerReviewTitle(status);
    await this.prisma.notification.create({
      data: {
        userId,
        title,
        body: reason,
        type: NotificationType.system,
        data: this.json({
          seller_verification_id: verificationId,
          status: status.toLowerCase(),
        }),
      },
    });
  }

  private sellerReviewTitle(status: SellerVerificationStatus): string {
    switch (status) {
      case SellerVerificationStatus.APPROVED:
        return 'Seller approved';
      case SellerVerificationStatus.REJECTED:
        return 'Seller rejected';
      case SellerVerificationStatus.SUSPENDED:
        return 'Seller suspended';
      case SellerVerificationStatus.NEEDS_MORE_DOCUMENTS:
      case SellerVerificationStatus.NEEDS_MORE_INFO:
        return 'More seller documents needed';
      case SellerVerificationStatus.UNDER_REVIEW:
        return 'Seller under review';
      default:
        return 'Seller application updated';
    }
  }

  private json(value: unknown): Prisma.InputJsonValue {
    return value as Prisma.InputJsonValue;
  }

  private async requireUser(id: string): Promise<User> {
    const user = await this.users.findById(id);
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  private async handleFailedLogin(
    user: User,
    identifier: string,
    context: RequestContext,
  ) {
    const failedLoginCount = user.failedLoginCount + 1;
    const lockedUntil =
      failedLoginCount >= 5 ? new Date(Date.now() + 15 * 60_000) : null;
    await this.prisma.user.update({
      where: { id: user.id },
      data: { failedLoginCount, lockedUntil },
    });
    await this.recordLoginAttempt(
      user.id,
      identifier,
      false,
      lockedUntil ? 'locked' : 'invalid_credentials',
      context,
      lockedUntil ? AuditSeverity.CRITICAL : AuditSeverity.WARNING,
    );
  }

  private async recordLoginAttempt(
    userId: string | null,
    identifier: string,
    success: boolean,
    reason: string | null,
    context: RequestContext,
    severity: AuditSeverity = AuditSeverity.INFO,
  ) {
    await this.prisma.loginAttempt.create({
      data: {
        userId: userId ?? undefined,
        phone: identifier,
        success,
        reason: reason ?? undefined,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        severity,
      },
    });
    await this.audit.record({
      actorId: userId,
      action: 'login',
      category: 'auth',
      outcome: success ? 'success' : reason ?? 'failure',
      severity,
      context,
    });
    await this.prisma.securityEvent.create({
      data: {
        actorId: userId ?? undefined,
        type: success
          ? SecurityEventType.LOGIN_SUCCESS
          : SecurityEventType.LOGIN_FAILURE,
        riskLevel: success
          ? RiskLevel.LOW
          : severity === AuditSeverity.CRITICAL
            ? RiskLevel.HIGH
            : RiskLevel.MEDIUM,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        metadata: {
          identifier,
          reason,
        },
      },
    });
  }

  private assertStrongPassword(password: string) {
    const strongEnough =
      password.length >= 10 &&
      /[a-z]/.test(password) &&
      /[A-Z]/.test(password) &&
      /[0-9]/.test(password) &&
      /[^A-Za-z0-9]/.test(password);
    if (!strongEnough) {
      throw new BadRequestException({
        code: 'WEAK_PASSWORD',
        message:
          'Password must include upper and lower case letters, a number, and a symbol',
      });
    }
  }

  private async generateUsername(name: string): Promise<string> {
    const base =
      name
        .toLowerCase()
        .replace(/[^a-z0-9_]/g, '_')
        .replace(/_+/g, '_')
        .replace(/^_|_$/g, '')
        .slice(0, 20) || 'reem_user';

    let username = base;
    for (let attempt = 0; attempt < 12; attempt++) {
      if (!(await this.users.usernameTaken(username))) return username;
      username = `${base}_${randomInt(10_000)}`;
    }
    return `${base}_${Date.now()}`;
  }

  private serializeSellerVerification(verification: SellerVerification) {
    return {
      id: verification.id,
      status: verification.status.toLowerCase(),
      business_name: verification.businessName,
      legal_name: verification.legalName,
      business_category: verification.businessCategory,
      store_description: verification.storeDescription,
      store_logo_url: verification.storeLogoUrl,
      contact_phone: verification.contactPhone,
      contact_email: verification.contactEmail,
      business_address: verification.businessAddress,
      warehouse_address: verification.warehouseAddress,
      commercial_registration: verification.commercialRegistration,
      government_id_url: verification.governmentIdUrl,
      business_license_url: verification.businessLicenseUrl,
      tax_id: verification.taxId,
      bank_name: verification.bankName,
      account_holder: verification.accountHolder,
      iban: verification.iban,
      payment_information: verification.paymentInformation,
      shipping_methods: verification.shippingMethods,
      return_policy: verification.returnPolicy,
      product_categories: verification.productCategories,
      years_experience: verification.yearsExperience,
      website: verification.website,
      social_media_links: verification.socialMediaLinks,
      document_urls: verification.documentUrls,
      review_reason: verification.reviewReason,
      rejection_reason: verification.rejectionReason,
      reviewed_by: verification.reviewedBy,
      reviewed_at: verification.reviewedAt?.toISOString() ?? null,
      submitted_at: verification.submittedAt.toISOString(),
      updated_at: verification.updatedAt.toISOString(),
    };
  }
}
