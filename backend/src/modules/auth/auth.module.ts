import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { AuthRepository } from './auth.repository';
import { PasswordService } from './password.service';
import { TokenService } from './token.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { OtpService } from './otp.service';
import { DeviceService } from './device.service';
import { AuditService } from './audit.service';
import { SocialIdentityService } from './social-identity.service';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    // Secrets/expiry are passed explicitly per-sign in TokenService.
    JwtModule.register({}),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    AuthRepository,
    PasswordService,
    TokenService,
    OtpService,
    DeviceService,
    AuditService,
    SocialIdentityService,
    JwtStrategy,
  ],
  exports: [TokenService, PasswordService, AuditService],
})
export class AuthModule {}
