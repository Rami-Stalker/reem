import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import {
  AuditSeverity,
  AuthProvider,
  OtpPurpose,
  Prisma,
  SellerVerification,
  SellerVerificationStatus,
  SessionStatus,
  User,
  UserRole,
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
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from './audit.service';
import { SocialAuthDto } from './dto/social-auth.dto';
import { SocialIdentityService } from './social-identity.service';
import {
  ChangePasswordDto,
  ReviewSellerVerificationDto,
  SecuritySettingsDto,
  SubmitSellerVerificationDto,
  UpdateAccountDto,
} from './dto/account.dto';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly users: AuthRepository,
    private readonly passwords: PasswordService,
    private readonly tokens: TokenService,
    private readonly otp: OtpService,
    private readonly devices: DeviceService,
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly social: SocialIdentityService,
  ) {}

  async register(dto: RegisterDto, context: RequestContext) {
    if (
      dto.role === UserRole.ADMIN ||
      dto.role === UserRole.SUPER_ADMIN ||
      dto.role === UserRole.SUPPORT
    ) {
      throw new ForbiddenException('Cannot self-register as a privileged role');
    }
    this.assertStrongPassword(dto.password);

    const phone = dto.phone.trim();
    const email = dto.email?.trim().toLowerCase();
    const [existingPhone, existingEmail] = await Promise.all([
      this.users.findByPhone(phone),
      email ? this.users.findByEmail(email) : Promise.resolve(null),
    ]);
    if (existingPhone) {
      throw new ConflictException('Phone number is already registered');
    }
    if (existingEmail) {
      throw new ConflictException('Email is already registered');
    }

    const passwordHash = await this.passwords.hash(dto.password);
    const username = await this.generateUsername(dto.name);

    const user = await this.users.create({
      name: dto.name.trim(),
      email,
      phone,
      username,
      passwordHash,
      role: dto.role ?? UserRole.CUSTOMER,
      imageUrl: `https://i.pravatar.cc/150?u=${encodeURIComponent(phone)}`,
    });

    const device = await this.devices.resolveDevice(user.id, context);
    const tokens = await this.tokens.issueTokens(user, {
      deviceId: device.id,
      context,
    });
    await this.audit.record({
      actorId: user.id,
      action: 'register',
      category: 'auth',
      outcome: 'success',
      context,
    });

    return {
      ...this.authResponse(user, tokens),
      verification: {
        phone_verified: false,
      },
    };
  }

  async login(dto: LoginDto, context: RequestContext) {
    const phone = dto.phone.trim();
    const user = await this.users.findByPhone(phone);

    if (!user || !user.passwordHash) {
      await this.recordLoginAttempt(null, phone, false, 'invalid_credentials', context);
      throw new UnauthorizedException('Invalid phone number or password');
    }
    if (user.disabledAt) {
      await this.recordLoginAttempt(user.id, phone, false, 'disabled', context);
      throw new ForbiddenException('Account is disabled');
    }
    if (user.lockedUntil && user.lockedUntil > new Date()) {
      await this.recordLoginAttempt(user.id, phone, false, 'locked', context);
      throw new ForbiddenException('Too many attempts. Try again later.');
    }

    const valid = await this.passwords.verify(dto.password, user.passwordHash);
    if (!valid) {
      await this.handleFailedLogin(user, phone, context);
      throw new UnauthorizedException('Invalid phone number or password');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        failedLoginCount: 0,
        lockedUntil: null,
        lastLoginAt: new Date(),
      },
    });

    const device = await this.devices.resolveDevice(user.id, {
      ...context,
      deviceName: dto.device_name ?? context.deviceName,
      platform: dto.platform ?? context.platform,
      appVersion: dto.app_version ?? context.appVersion,
      fingerprint: dto.device_fingerprint ?? context.fingerprint,
    });
    const tokens = await this.tokens.issueTokens(user, {
      deviceId: device.id,
      context,
    });
    await this.recordLoginAttempt(user.id, phone, true, null, context);

    return {
      ...this.authResponse(user, tokens),
      device_verification_required:
        user.deviceVerificationRequired && !device.verifiedAt,
    };
  }

  async socialSignIn(dto: SocialAuthDto, context: RequestContext) {
    const identity = await this.social.verify(dto);
    const linked = await this.users.findLinkedAccount(
      identity.provider,
      identity.providerUserId,
    );

    let user = linked?.user ?? null;
    if (!user && identity.email) {
      user = await this.users.findByEmail(identity.email.toLowerCase());
    }
    if (!user) {
      user = await this.users.create({
        name:
          identity.name?.trim() ||
          identity.email?.split('@')[0] ||
          `${identity.provider.toLowerCase()} shopper`,
        username: await this.generateUsername(
          identity.name || identity.email || identity.providerUserId,
        ),
        email: identity.email?.toLowerCase(),
        phone: null,
        passwordHash: null,
        role: UserRole.CUSTOMER,
        isVerified: identity.emailVerified,
        imageUrl: `https://i.pravatar.cc/150?u=${encodeURIComponent(
          identity.providerUserId,
        )}`,
      });
    }

    await this.users.linkAccount({
      userId: user.id,
      provider: identity.provider,
      providerUserId: identity.providerUserId,
      email: identity.email?.toLowerCase(),
      displayName: identity.name,
    });

    const device = await this.devices.resolveDevice(user.id, {
      ...context,
      deviceName: dto.device_name ?? context.deviceName,
      platform: dto.platform ?? context.platform,
      appVersion: dto.app_version ?? context.appVersion,
      fingerprint: dto.device_fingerprint ?? context.fingerprint,
    });
    const tokens = await this.tokens.issueTokens(user, {
      deviceId: device.id,
      context,
    });

    await this.audit.record({
      actorId: user.id,
      action: `${identity.provider.toLowerCase()}_sign_in`,
      category: 'auth',
      outcome: 'success',
      context,
    });

    return this.authResponse(user, tokens);
  }

  async refresh(refreshToken: string, context: RequestContext) {
    const { user, tokens } = await this.tokens.rotate(refreshToken, context);
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

  async me(userId: string) {
    const user = await this.requireUser(userId);
    return { user: serializeUser(user) };
  }

  async forgotPassword(phone: string, context: RequestContext) {
    const result = await this.otp.request({
      phone,
      purpose: OtpPurpose.PASSWORD_RESET,
      context,
    });
    this.logger.log(`[otp] Password reset requested for ${phone}`);
    return {
      message: 'If that number is registered, a reset code has been sent.',
      ...result,
    };
  }

  requestOtp(phone: string, purpose: OtpPurpose, context: RequestContext) {
    return this.otp.request({ phone, purpose, context });
  }

  verifyOtp(phone: string, purpose: OtpPurpose, code: string) {
    return this.otp.verify(phone, purpose, code);
  }

  async resetPassword(phone: string, code: string, newPassword: string) {
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
    }
    return { message: 'Password was reset successfully' };
  }

  async account(userId: string) {
    const user = await this.requireUser(userId);
    const [linkedAccounts, sellerVerification, permissions] = await Promise.all([
      this.prisma.linkedAccount.findMany({
        where: { userId },
        orderBy: { linkedAt: 'asc' },
      }),
      this.prisma.sellerVerification.findUnique({ where: { userId } }),
      this.tokens.permissionsFor(user.id, user.role),
    ]);

    return {
      user: serializeUser(user),
      permissions,
      linked_accounts: linkedAccounts.map((account) => ({
        id: account.id,
        provider: account.provider.toLowerCase(),
        email: account.email,
        display_name: account.displayName,
        linked_at: account.linkedAt.toISOString(),
        last_used_at: account.lastUsedAt?.toISOString() ?? null,
      })),
      security: {
        mfa_enabled: user.mfaEnabled,
        device_verification_required: user.deviceVerificationRequired,
      },
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
      const email = dto.email.trim().toLowerCase();
      const existing = await this.users.findByEmail(email);
      if (existing && existing.id !== userId) {
        throw new ConflictException('Email is already registered');
      }
      data.email = email;
    }
    if (dto.phone !== undefined) {
      const phone = dto.phone.trim();
      const existing = await this.users.findByPhone(phone);
      if (existing && existing.id !== userId) {
        throw new ConflictException('Phone number is already registered');
      }
      data.phone = phone;
      data.isVerified = false;
    }

    const user = await this.prisma.user.update({ where: { id: userId }, data });
    await this.audit.record({
      actorId: userId,
      action: 'update_account',
      category: 'account',
      outcome: 'success',
    });
    return { user: serializeUser(user) };
  }

  async changePassword(userId: string, dto: ChangePasswordDto, sessionId?: string) {
    this.assertStrongPassword(dto.new_password);
    const user = await this.requireUser(userId);
    if (user.passwordHash) {
      if (!dto.current_password) {
        throw new BadRequestException('Current password is required');
      }
      const valid = await this.passwords.verify(
        dto.current_password,
        user.passwordHash,
      );
      if (!valid) throw new UnauthorizedException('Current password is invalid');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: await this.passwords.hash(dto.new_password) },
    });
    await this.tokens.revokeAll(userId, sessionId);
    await this.audit.record({
      actorId: userId,
      action: 'change_password',
      category: 'account',
      outcome: 'success',
      severity: AuditSeverity.WARNING,
    });
    return { message: 'Password changed successfully' };
  }

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

  listDevices(userId: string) {
    return this.devices.list(userId);
  }

  renameDevice(userId: string, deviceId: string, name: string) {
    return this.devices.rename(userId, deviceId, name);
  }

  trustDevice(userId: string, deviceId: string) {
    return this.devices.trust(userId, deviceId);
  }

  revokeDevice(userId: string, deviceId: string) {
    return this.devices.revoke(userId, deviceId);
  }

  listSessions(userId: string) {
    return this.tokens.listSessions(userId);
  }

  revokeSession(userId: string, sessionId: string) {
    return this.tokens.revokeSession(userId, sessionId);
  }

  async linkAccount(userId: string, dto: SocialAuthDto) {
    const identity = await this.social.verify(dto);
    const existing = await this.users.findLinkedAccount(
      identity.provider,
      identity.providerUserId,
    );
    if (existing && existing.userId !== userId) {
      throw new ConflictException('This account is linked to another user');
    }

    await this.users.linkAccount({
      userId,
      provider: identity.provider,
      providerUserId: identity.providerUserId,
      email: identity.email?.toLowerCase(),
      displayName: identity.name,
    });

    await this.audit.record({
      actorId: userId,
      action: `link_${identity.provider.toLowerCase()}`,
      category: 'account',
      outcome: 'success',
    });

    return this.account(userId);
  }

  async unlinkAccount(userId: string, provider: AuthProvider) {
    const user = await this.requireUser(userId);
    const linkedCount = await this.prisma.linkedAccount.count({
      where: { userId },
    });
    if (!user.passwordHash && linkedCount <= 1) {
      throw new BadRequestException(
        'Add a password or another provider before unlinking this account',
      );
    }
    await this.prisma.linkedAccount.deleteMany({
      where: { userId, provider },
    });
    return this.account(userId);
  }

  async submitSellerVerification(
    userId: string,
    dto: SubmitSellerVerificationDto,
  ) {
    const verification = await this.prisma.sellerVerification.upsert({
      where: { userId },
      update: {
        status: SellerVerificationStatus.PENDING,
        businessName: dto.business_name.trim(),
        legalName: dto.legal_name.trim(),
        taxId: dto.tax_id?.trim(),
        documentUrls: dto.document_urls,
        rejectionReason: null,
        reviewedAt: null,
        reviewedBy: null,
        submittedAt: new Date(),
      },
      create: {
        userId,
        status: SellerVerificationStatus.PENDING,
        businessName: dto.business_name.trim(),
        legalName: dto.legal_name.trim(),
        taxId: dto.tax_id?.trim(),
        documentUrls: dto.document_urls,
      },
    });
    await this.prisma.user.update({
      where: { id: userId },
      data: { role: UserRole.SELLER },
    });
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

  async reviewSellerVerification(
    reviewerId: string,
    verificationId: string,
    dto: ReviewSellerVerificationDto,
  ) {
    const status = dto.status as SellerVerificationStatus;
    const verification = await this.prisma.sellerVerification.update({
      where: { id: verificationId },
      data: {
        status,
        rejectionReason: dto.rejection_reason,
        reviewedBy: reviewerId,
        reviewedAt: new Date(),
        ...(status === SellerVerificationStatus.APPROVED && {
          user: { update: { role: UserRole.SELLER, isVerified: true } },
        }),
        ...(status !== SellerVerificationStatus.APPROVED && {
          user: { update: { isVerified: false } },
        }),
      },
    });
    return this.serializeSellerVerification(verification);
  }

  private authResponse(user: User, tokens: TokenPair) {
    return { user: serializeUser(user), tokens };
  }

  private async requireUser(id: string): Promise<User> {
    const user = await this.users.findById(id);
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  private async handleFailedLogin(
    user: User,
    phone: string,
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
      phone,
      false,
      lockedUntil ? 'locked' : 'invalid_credentials',
      context,
      lockedUntil ? AuditSeverity.CRITICAL : AuditSeverity.WARNING,
    );
  }

  private async recordLoginAttempt(
    userId: string | null,
    phone: string,
    success: boolean,
    reason: string | null,
    context: RequestContext,
    severity: AuditSeverity = AuditSeverity.INFO,
  ) {
    await this.prisma.loginAttempt.create({
      data: {
        userId: userId ?? undefined,
        phone,
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
  }

  private assertStrongPassword(password: string) {
    const strongEnough =
      password.length >= 8 &&
      /[a-z]/.test(password) &&
      /[A-Z]/.test(password) &&
      /[0-9]/.test(password);
    if (!strongEnough) {
      throw new BadRequestException(
        'Password must include upper and lower case letters and a number',
      );
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
      username = `${base}_${Math.floor(Math.random() * 9999)}`;
    }
    return `${base}_${Date.now()}`;
  }

  private serializeSellerVerification(verification: SellerVerification) {
    return {
      id: verification.id,
      status: verification.status.toLowerCase(),
      business_name: verification.businessName,
      legal_name: verification.legalName,
      tax_id: verification.taxId,
      document_urls: verification.documentUrls,
      rejection_reason: verification.rejectionReason,
      reviewed_by: verification.reviewedBy,
      reviewed_at: verification.reviewedAt?.toISOString() ?? null,
      submitted_at: verification.submittedAt.toISOString(),
      updated_at: verification.updatedAt.toISOString(),
    };
  }
}
