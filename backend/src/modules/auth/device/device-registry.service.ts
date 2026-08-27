import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  DeviceKey,
  DeviceKeyStorage,
  DeviceTrustLevel,
  RiskLevel,
  SecurityEventType,
  SessionStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { publicKeyFromRaw } from '../../../common/crypto/ed25519';
import { RequestContext } from '../interfaces/request-context.interface';
import { RegisterDeviceKeyDto } from '../dto/device-key.dto';

/**
 * The register of devices the platform knows.
 *
 * Registration is open — anyone can present a public key, and that is fine:
 * holding a key proves nothing by itself. What the key gives us is a stable,
 * unforgeable *name* for a device, so that trust, revocation and fraud signals
 * finally have something durable to attach to. Trust is conferred elsewhere,
 * by completing an OTP challenge on the device; there is no endpoint that
 * simply declares a device trusted, because the one that existed took nothing
 * but a session and a device id.
 */
@Injectable()
export class DeviceRegistryService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Registers a public key, or returns the existing registration for it.
   *
   * Idempotent on the key itself: a reinstall generates a new key and gets a
   * new row, the same install returns the same row.
   */
  async register(
    dto: RegisterDeviceKeyDto,
    context: RequestContext,
    userId?: string,
  ): Promise<DeviceKey> {
    // Reject anything that is not a usable Ed25519 key before it is stored —
    // a malformed key would otherwise sit in the table and fail verification
    // forever, which looks like a device that mysteriously stopped working.
    try {
      publicKeyFromRaw(dto.public_key);
    } catch {
      throw new ForbiddenException('Invalid device public key');
    }

    const existing = await this.prisma.deviceKey.findUnique({
      where: { publicKey: dto.public_key },
    });

    if (existing) {
      if (existing.revokedAt) {
        throw new ForbiddenException('This device has been revoked');
      }
      return this.prisma.deviceKey.update({
        where: { id: existing.id },
        data: {
          userId: existing.userId ?? userId,
          label: dto.label ?? existing.label,
          platform: dto.platform ?? existing.platform,
          osVersion: dto.os_version ?? existing.osVersion,
          model: dto.model ?? existing.model,
          appVersion: dto.app_version ?? existing.appVersion,
          keyStorage: dto.key_storage ?? existing.keyStorage,
          hardwareBacked: dto.hardware_backed ?? existing.hardwareBacked,
          lastSeenAt: new Date(),
        },
      });
    }

    const deviceKey = await this.prisma.deviceKey.create({
      data: {
        userId,
        publicKey: dto.public_key,
        keyStorage: dto.key_storage ?? DeviceKeyStorage.SOFTWARE,
        hardwareBacked: dto.hardware_backed ?? false,
        label: dto.label,
        platform: dto.platform ?? context.platform,
        osVersion: dto.os_version,
        model: dto.model,
        appVersion: dto.app_version ?? context.appVersion,
      },
    });

    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        type: SecurityEventType.DEVICE_CREATED,
        riskLevel: RiskLevel.MEDIUM,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        resource: `device_key:${deviceKey.id}`,
        metadata: {
          platform: deviceKey.platform,
          hardware_backed: deviceKey.hardwareBacked,
          key_storage: deviceKey.keyStorage,
        },
      },
    });

    return deviceKey;
  }

  /** Claims an unowned key for a user at sign-in, and refuses a revoked one. */
  async attachToUser(deviceKeyId: string, userId: string): Promise<DeviceKey> {
    const key = await this.prisma.deviceKey.findUnique({
      where: { id: deviceKeyId },
    });
    if (!key) throw new NotFoundException('Unknown device');
    if (key.revokedAt) throw new ForbiddenException('This device has been revoked');
    if (key.trustLevel === DeviceTrustLevel.BLOCKED) {
      throw new ForbiddenException('This device has been blocked');
    }
    if (key.userId && key.userId !== userId) {
      // A shared handset is normal here — a household with one phone — so the
      // key is re-pointed rather than refused, and the move is recorded.
      await this.prisma.securityEvent.create({
        data: {
          actorId: userId,
          type: SecurityEventType.DEVICE_CREATED,
          riskLevel: RiskLevel.MEDIUM,
          resource: `device_key:${key.id}`,
          metadata: { reassigned_from: key.userId },
        },
      });
    }

    return this.prisma.deviceKey.update({
      where: { id: key.id },
      data: { userId, lastSeenAt: new Date() },
    });
  }

  /**
   * Marks the device as verified. Called only after an OTP challenge has been
   * completed on it — this is the entire path to a trusted device now.
   */
  async markVerified(deviceKeyId: string): Promise<void> {
    await this.prisma.deviceKey.updateMany({
      where: { id: deviceKeyId, revokedAt: null },
      data: {
        trustLevel: DeviceTrustLevel.TRUSTED,
        verifiedAt: new Date(),
      },
    });
    await this.prisma.securityEvent.create({
      data: {
        type: SecurityEventType.DEVICE_TRUSTED,
        riskLevel: RiskLevel.LOW,
        resource: `device_key:${deviceKeyId}`,
      },
    });
  }

  async list(userId: string) {
    const keys = await this.prisma.deviceKey.findMany({
      where: { userId, revokedAt: null },
      orderBy: { lastSeenAt: 'desc' },
      include: { sessions: { where: { status: SessionStatus.ACTIVE } } },
    });

    return keys.map((key) => ({
      id: key.id,
      label: key.label ?? key.model ?? key.platform ?? 'جهاز',
      platform: key.platform,
      os_version: key.osVersion,
      model: key.model,
      app_version: key.appVersion,
      trust_level: key.trustLevel.toLowerCase(),
      hardware_backed: key.hardwareBacked,
      key_storage: key.keyStorage.toLowerCase(),
      active_sessions: key.sessions.length,
      verified_at: key.verifiedAt?.toISOString() ?? null,
      first_seen_at: key.firstSeenAt.toISOString(),
      last_seen_at: key.lastSeenAt.toISOString(),
    }));
  }

  async rename(userId: string, deviceKeyId: string, label: string) {
    await this.requireOwned(userId, deviceKeyId);
    const key = await this.prisma.deviceKey.update({
      where: { id: deviceKeyId },
      data: { label: label.trim() },
    });
    return { id: key.id, label: key.label };
  }

  /**
   * Revokes the device and everything issued to it, permanently.
   *
   * Durable this time: revocation is recorded against a key that cannot be
   * re-derived. The old scheme revoked a hash of headers including the IP, so
   * the same handset came back as a brand-new device on the next network.
   */
  async revoke(userId: string, deviceKeyId: string, reason = 'user_revoked') {
    await this.requireOwned(userId, deviceKeyId);
    const now = new Date();

    await this.prisma.$transaction([
      this.prisma.deviceKey.update({
        where: { id: deviceKeyId },
        data: {
          revokedAt: now,
          revokedReason: reason,
          trustLevel: DeviceTrustLevel.BLOCKED,
        },
      }),
      this.prisma.session.updateMany({
        where: { userId, deviceKeyId, status: SessionStatus.ACTIVE },
        data: {
          status: SessionStatus.REVOKED,
          revokedAt: now,
          revokedReason: 'device_revoked',
        },
      }),
      this.prisma.refreshToken.updateMany({
        where: { userId, deviceKeyId, revokedAt: null },
        data: { revokedAt: now },
      }),
    ]);

    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        type: SecurityEventType.DEVICE_REVOKED,
        riskLevel: RiskLevel.HIGH,
        resource: `device_key:${deviceKeyId}`,
        metadata: { reason },
      },
    });

    return { message: 'Device revoked' };
  }

  /**
   * The `revokedAt: null` filter is the fix for a real hole: only `list()`
   * filtered revoked devices, so a revoked device could be operated on again
   * by id and resurrected.
   */
  private async requireOwned(userId: string, deviceKeyId: string) {
    const key = await this.prisma.deviceKey.findFirst({
      where: { id: deviceKeyId, userId, revokedAt: null },
    });
    if (!key) throw new NotFoundException('Device not found');
    return key;
  }
}
