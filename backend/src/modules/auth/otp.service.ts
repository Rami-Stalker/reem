import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { OtpChannel, OtpPurpose, OtpStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { PasswordService } from './password.service';
import { RequestContext } from './interfaces/request-context.interface';

interface RequestOtpInput {
  phone: string;
  purpose: OtpPurpose;
  channel?: OtpChannel;
  userId?: string;
  context?: RequestContext;
}

@Injectable()
export class OtpService {
  private readonly ttlMs = 10 * 60_000;
  private readonly maxPerMinute = 1;
  private readonly maxPerHour = 5;

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
  ) {}

  async request(input: RequestOtpInput) {
    await this.assertRateLimit(input.phone, input.purpose);

    const code = this.generateCode();
    const codeHash = await this.passwords.hash(code);
    const expiresAt = new Date(Date.now() + this.ttlMs);
    const user =
      input.userId || !input.phone
        ? null
        : await this.prisma.user.findUnique({ where: { phone: input.phone } });

    const request = await this.prisma.otpRequest.create({
      data: {
        userId: input.userId ?? user?.id,
        destination: input.phone,
        channel: input.channel ?? OtpChannel.SMS,
        purpose: input.purpose,
        codeHash,
        expiresAt,
        ipAddress: input.context?.ipAddress,
        userAgent: input.context?.userAgent,
      },
    });

    return {
      otp_request_id: request.id,
      expires_at: expiresAt.toISOString(),
      // Development-only visibility keeps local testing operational without
      // needing an SMS provider.
      debug_code: process.env.NODE_ENV === 'production' ? undefined : code,
    };
  }

  async verify(phone: string, purpose: OtpPurpose, code: string) {
    const request = await this.prisma.otpRequest.findFirst({
      where: {
        destination: phone,
        purpose,
        status: OtpStatus.PENDING,
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!request) {
      throw new BadRequestException('Invalid or expired verification code');
    }

    const now = new Date();
    if (request.expiresAt < now) {
      await this.prisma.otpRequest.update({
        where: { id: request.id },
        data: { status: OtpStatus.EXPIRED },
      });
      throw new BadRequestException('Invalid or expired verification code');
    }

    if (request.attempts >= request.maxAttempts) {
      await this.prisma.otpRequest.update({
        where: { id: request.id },
        data: { status: OtpStatus.LOCKED },
      });
      throw new BadRequestException('Too many verification attempts');
    }

    const valid = await this.passwords.verify(code, request.codeHash);
    if (!valid) {
      await this.prisma.otpRequest.update({
        where: { id: request.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException('Invalid or expired verification code');
    }

    await this.prisma.otpRequest.update({
      where: { id: request.id },
      data: { status: OtpStatus.VERIFIED, verifiedAt: now },
    });

    if (purpose === OtpPurpose.PHONE_VERIFICATION) {
      await this.prisma.user.updateMany({
        where: { phone },
        data: { isVerified: true },
      });
    }

    return { verified: true };
  }

  private async assertRateLimit(phone: string, purpose: OtpPurpose) {
    const now = Date.now();
    const [minuteCount, hourCount] = await Promise.all([
      this.prisma.otpRequest.count({
        where: {
          destination: phone,
          purpose,
          createdAt: { gt: new Date(now - 60_000) },
        },
      }),
      this.prisma.otpRequest.count({
        where: {
          destination: phone,
          purpose,
          createdAt: { gt: new Date(now - 60 * 60_000) },
        },
      }),
    ]);

    if (minuteCount >= this.maxPerMinute || hourCount >= this.maxPerHour) {
      throw new HttpException(
        'Too many verification codes requested',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private generateCode(): string {
    return `${Math.floor(100000 + Math.random() * 900000)}`;
  }
}
