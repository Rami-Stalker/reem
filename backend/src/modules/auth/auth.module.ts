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
import { DeviceRegistryService } from './device/device-registry.service';
import { DeviceProofService } from './device/device-proof.service';
import { StepUpService } from './step-up/step-up.service';
import { RecoveryService } from './recovery/recovery.service';
import { TotpService } from './totp/totp.service';
import { PrivilegedMfaInvariant } from './totp/privileged-mfa.invariant';
import { AuditService } from './audit.service';
import { GuestService } from './guest.service';
import { OtpDeliveryModule } from './otp/otp-delivery.module';
import { RegistrationTicketService } from './login/registration-ticket.service';
import { PhoneChangeService } from './phone-change/phone-change.service';
import { AccountRecoveryService } from './recovery/account-recovery.service';
import { AuthRetentionCron } from './retention/auth-retention.cron';
import { SecurityAdminController } from './admin/security-admin.controller';
import { SecurityForensicsService } from './admin/security-forensics.service';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    // Secrets/expiry are passed explicitly per-sign in TokenService.
    JwtModule.register({}),
    // Getting the code onto a handset is a subsystem of its own: an outbox, a
    // priority chain of transports, receipts and budget breakers.
    OtpDeliveryModule,
  ],
  controllers: [AuthController, SecurityAdminController],
  providers: [
    AuthService,
    AuthRepository,
    PasswordService,
    TokenService,
    OtpService,
    DeviceService,
    DeviceRegistryService,
    DeviceProofService,
    StepUpService,
    RecoveryService,
    TotpService,
    AuditService,
    GuestService,
    RegistrationTicketService,
    PhoneChangeService,
    AccountRecoveryService,
    SecurityForensicsService,
    AuthRetentionCron,
    PrivilegedMfaInvariant,
    JwtStrategy,
  ],
  exports: [
    AuthService,
    DeviceRegistryService,
    DeviceProofService,
    StepUpService,
    RecoveryService,
    TotpService,
    TokenService,
    PasswordService,
    AuditService,
    GuestService,
    PhoneChangeService,
    AccountRecoveryService,
  ],
})
export class AuthModule {}
