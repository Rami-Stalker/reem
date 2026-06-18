import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { createHash } from 'crypto';
import { Device, DeviceTrustLevel, SessionStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { RequestContext } from './interfaces/request-context.interface';

@Injectable()
export class DeviceService {
  constructor(private readonly prisma: PrismaService) {}

  async resolveDevice(userId: string, context: RequestContext): Promise<Device> {
    const fingerprintHash = this.fingerprintHash(context);
    const name =
      context.deviceName ||
      this.nameFromUserAgent(context.userAgent) ||
      'Unknown device';

    const existing = await this.prisma.device.findUnique({
      where: {
        userId_fingerprintHash: {
          userId,
          fingerprintHash,
        },
      },
    });

    if (existing?.trustLevel === DeviceTrustLevel.BLOCKED) {
      throw new ForbiddenException('This device has been blocked');
    }

    if (existing) {
      return this.prisma.device.update({
        where: { id: existing.id },
        data: {
          name: existing.name || name,
          platform: context.platform ?? existing.platform,
          appVersion: context.appVersion ?? existing.appVersion,
          ipAddress: context.ipAddress,
          userAgent: context.userAgent,
          lastSeenAt: new Date(),
          revokedAt: null,
        },
      });
    }

    return this.prisma.device.create({
      data: {
        userId,
        fingerprintHash,
        name,
        platform: context.platform,
        appVersion: context.appVersion,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
      },
    });
  }

  async list(userId: string) {
    const devices = await this.prisma.device.findMany({
      where: { userId, revokedAt: null },
      orderBy: { lastSeenAt: 'desc' },
    });
    return devices.map(this.serializeDevice);
  }

  async rename(userId: string, deviceId: string, name: string) {
    await this.requireDevice(userId, deviceId);
    const device = await this.prisma.device.update({
      where: { id: deviceId },
      data: { name: name.trim() },
    });
    return this.serializeDevice(device);
  }

  async trust(userId: string, deviceId: string) {
    await this.requireDevice(userId, deviceId);
    const device = await this.prisma.device.update({
      where: { id: deviceId },
      data: {
        trustLevel: DeviceTrustLevel.TRUSTED,
        verifiedAt: new Date(),
      },
    });
    return this.serializeDevice(device);
  }

  async revoke(userId: string, deviceId: string) {
    await this.requireDevice(userId, deviceId);
    const now = new Date();
    await this.prisma.$transaction([
      this.prisma.device.update({
        where: { id: deviceId },
        data: { revokedAt: now, trustLevel: DeviceTrustLevel.BLOCKED },
      }),
      this.prisma.session.updateMany({
        where: { userId, deviceId, status: SessionStatus.ACTIVE },
        data: { status: SessionStatus.REVOKED, revokedAt: now },
      }),
      this.prisma.refreshToken.updateMany({
        where: { userId, deviceId, revokedAt: null },
        data: { revokedAt: now },
      }),
    ]);
    return { message: 'Device revoked' };
  }

  fingerprintHash(context: RequestContext): string {
    const source = [
      context.fingerprint,
      context.deviceId,
      context.userAgent,
      context.platform,
      context.appVersion,
      context.ipAddress,
    ]
      .filter(Boolean)
      .join('|');

    return createHash('sha256')
      .update(source || 'unknown-device')
      .digest('hex');
  }

  private async requireDevice(userId: string, deviceId: string) {
    const device = await this.prisma.device.findFirst({
      where: { id: deviceId, userId },
    });
    if (!device) throw new NotFoundException('Device not found');
    return device;
  }

  private nameFromUserAgent(userAgent?: string): string | null {
    if (!userAgent) return null;
    if (userAgent.includes('Android')) return 'Android device';
    if (userAgent.includes('iPhone') || userAgent.includes('iPad')) {
      return 'Apple device';
    }
    if (userAgent.includes('Windows')) return 'Windows device';
    if (userAgent.includes('Macintosh')) return 'Mac device';
    return 'Browser session';
  }

  private serializeDevice(device: Device) {
    return {
      id: device.id,
      name: device.name,
      platform: device.platform,
      app_version: device.appVersion,
      trust_level: device.trustLevel.toLowerCase(),
      ip_address: device.ipAddress,
      user_agent: device.userAgent,
      verified_at: device.verifiedAt?.toISOString() ?? null,
      last_seen_at: device.lastSeenAt.toISOString(),
      created_at: device.createdAt.toISOString(),
    };
  }
}
