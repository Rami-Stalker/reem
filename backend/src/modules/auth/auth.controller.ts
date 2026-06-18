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
import { AuthProvider, UserRole } from '@prisma/client';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import {
  RequestOtpDto,
  ResetPasswordDto,
  VerifyOtpDto,
} from './dto/otp.dto';
import {
  ChangePasswordDto,
  RenameDeviceDto,
  ReviewSellerVerificationDto,
  SecuritySettingsDto,
  SubmitSellerVerificationDto,
  UpdateAccountDto,
} from './dto/account.dto';
import { SocialAuthDto } from './dto/social-auth.dto';
import { requestContextFrom } from './interfaces/request-context.interface';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Throttle({ default: { limit: 8, ttl: 60_000 } })
  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  register(@Body() dto: RegisterDto, @Req() req: Request) {
    return this.auth.register(dto, requestContextFrom(req));
  }

  @Public()
  @Throttle({ default: { limit: 8, ttl: 60_000 } })
  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.auth.login(dto, requestContextFrom(req));
  }

  @Public()
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('social')
  @HttpCode(HttpStatus.OK)
  social(@Body() dto: SocialAuthDto, @Req() req: Request) {
    return this.auth.socialSignIn(dto, requestContextFrom(req));
  }

  @Public()
  @Post('refresh-token')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() dto: RefreshTokenDto, @Req() req: Request) {
    return this.auth.refresh(dto.refresh_token, requestContextFrom(req));
  }

  @Public()
  @Post('logout')
  @HttpCode(HttpStatus.OK)
  logout(@Body() dto: RefreshTokenDto, @Req() req: Request) {
    return this.auth.logout(dto.refresh_token, requestContextFrom(req));
  }

  @Post('logout-all')
  @HttpCode(HttpStatus.OK)
  logoutAll(@CurrentUser() user: AuthUser) {
    return this.auth.logoutAll(user.id);
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

  @Get('me')
  me(@CurrentUser('id') userId: string) {
    return this.auth.me(userId);
  }

  @Get('account')
  account(@CurrentUser('id') userId: string) {
    return this.auth.account(userId);
  }

  @Patch('account')
  updateAccount(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateAccountDto,
  ) {
    return this.auth.updateAccount(userId, dto);
  }

  @Patch('account/password')
  changePassword(
    @CurrentUser() user: AuthUser,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.auth.changePassword(user.id, dto, user.sessionId);
  }

  @Post('account/link')
  @HttpCode(HttpStatus.OK)
  linkAccount(@CurrentUser('id') userId: string, @Body() dto: SocialAuthDto) {
    return this.auth.linkAccount(userId, dto);
  }

  @Delete('account/link/:provider')
  @HttpCode(HttpStatus.OK)
  unlinkAccount(
    @CurrentUser('id') userId: string,
    @Param('provider') provider: string,
  ) {
    return this.auth.unlinkAccount(
      userId,
      provider.toUpperCase() as AuthProvider,
    );
  }

  @Patch('security')
  updateSecurity(
    @CurrentUser('id') userId: string,
    @Body() dto: SecuritySettingsDto,
  ) {
    return this.auth.updateSecuritySettings(userId, dto);
  }

  @Get('devices')
  devices(@CurrentUser('id') userId: string) {
    return this.auth.listDevices(userId);
  }

  @Patch('devices/:id')
  renameDevice(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RenameDeviceDto,
  ) {
    return this.auth.renameDevice(userId, id, dto.name);
  }

  @Post('devices/:id/trust')
  @HttpCode(HttpStatus.OK)
  trustDevice(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.auth.trustDevice(userId, id);
  }

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

  @Post('seller-verification')
  @HttpCode(HttpStatus.OK)
  submitSellerVerification(
    @CurrentUser('id') userId: string,
    @Body() dto: SubmitSellerVerificationDto,
  ) {
    return this.auth.submitSellerVerification(userId, dto);
  }

  @Get('seller-verification/me')
  mySellerVerification(@CurrentUser('id') userId: string) {
    return this.auth.mySellerVerification(userId);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Patch('seller-verification/:id/review')
  reviewSellerVerification(
    @CurrentUser('id') reviewerId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReviewSellerVerificationDto,
  ) {
    return this.auth.reviewSellerVerification(reviewerId, id, dto);
  }
}
