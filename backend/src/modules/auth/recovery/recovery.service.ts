import { Injectable, Logger } from '@nestjs/common';
import { RiskLevel, SecurityEventType } from '@prisma/client';
import { randomInt } from 'crypto';
import { PrismaService } from '../../../prisma/prisma.service';
import { PasswordService } from '../password.service';

/** Ten is the usual number: enough to survive losses, few enough to write down. */
const CODE_COUNT = 10;
/** Crockford-ish alphabet: no 0/O, no 1/I/L — these get copied by hand. */
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const GROUP = 5;

/**
 * Single-use recovery codes.
 *
 * They do two jobs. First, they are an AAL3 channel that is **not** the SIM —
 * without them the assurance ladder is defeated end to end by SIM possession,
 * which is the attack it exists to stop. Second, they are the only
 * self-service way back into an account whose number is gone.
 *
 * Adoption will be low, and the design assumes it: people do not reliably keep
 * ten codes on paper. That is why the support-mediated recovery path and the
 * optional password exist beside this rather than instead of it — this is one
 * leg of three, not the answer on its own.
 */
@Injectable()
export class RecoveryService {
  private readonly logger = new Logger(RecoveryService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
  ) {}

  /**
   * Issues a fresh set and invalidates every earlier one.
   *
   * The plaintext is returned exactly once and never stored — the codes are
   * argon2id-hashed like passwords, because unlike a six-digit OTP these live
   * for months and a database dump must not yield working ones.
   */
  async generate(userId: string): Promise<{ codes: string[]; generation: number }> {
    const latest = await this.prisma.recoveryCode.findFirst({
      where: { userId },
      orderBy: { generation: 'desc' },
      select: { generation: true },
    });
    const generation = (latest?.generation ?? 0) + 1;

    const codes = Array.from({ length: CODE_COUNT }, () => this.newCode());
    const hashes = await Promise.all(
      codes.map((code) => this.passwords.hash(this.normalize(code))),
    );

    await this.prisma.$transaction([
      // Older generations are dropped rather than left dormant: a code she
      // wrote down two sets ago must not still open the door.
      this.prisma.recoveryCode.deleteMany({ where: { userId } }),
      this.prisma.recoveryCode.createMany({
        data: hashes.map((codeHash) => ({ userId, codeHash, generation })),
      }),
    ]);

    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        type: SecurityEventType.PASSWORD_CHANGED,
        riskLevel: RiskLevel.HIGH,
        resource: 'recovery_codes',
        metadata: { action: 'recovery_codes_generated', generation },
      },
    });

    return { codes, generation };
  }

  /** What the settings screen shows: how many are left, without revealing any. */
  async status(userId: string) {
    const [total, used] = await Promise.all([
      this.prisma.recoveryCode.count({ where: { userId } }),
      this.prisma.recoveryCode.count({ where: { userId, usedAt: { not: null } } }),
    ]);
    const latest = await this.prisma.recoveryCode.findFirst({
      where: { userId },
      orderBy: { generation: 'desc' },
      select: { generation: true, createdAt: true },
    });

    return {
      configured: total > 0,
      remaining: total - used,
      total,
      generation: latest?.generation ?? 0,
      generated_at: latest?.createdAt?.toISOString() ?? null,
    };
  }

  /**
   * Spends one code. Returns false for anything that does not match a live
   * code — the caller must not distinguish "wrong code" from "no codes set up",
   * or the endpoint becomes an oracle for which accounts have recovery
   * configured.
   */
  async redeem(
    userId: string,
    code: string,
    deviceKeyId?: string,
  ): Promise<boolean> {
    const candidates = await this.prisma.recoveryCode.findMany({
      where: { userId, usedAt: null },
    });

    for (const candidate of candidates) {
      if (!(await this.passwords.verify(this.normalize(code), candidate.codeHash))) {
        continue;
      }

      // Compare-and-set, so two concurrent redemptions of one code cannot both
      // win — the same race that mattered for refresh tokens.
      const claimed = await this.prisma.recoveryCode.updateMany({
        where: { id: candidate.id, usedAt: null },
        data: { usedAt: new Date(), usedFromDeviceKeyId: deviceKeyId },
      });
      if (claimed.count === 0) return false;

      const remaining = await this.prisma.recoveryCode.count({
        where: { userId, usedAt: null },
      });
      await this.prisma.securityEvent.create({
        data: {
          actorId: userId,
          type: SecurityEventType.SUSPICIOUS_LOGIN,
          riskLevel: RiskLevel.HIGH,
          resource: 'recovery_codes',
          metadata: { action: 'recovery_code_redeemed', remaining },
        },
      });
      if (remaining <= 2) {
        this.logger.warn(
          `User ${userId} has ${remaining} recovery codes left`,
        );
      }
      return true;
    }

    return false;
  }

  /** `A1B2C-3D4E5` — grouped, unambiguous, easy to read off paper. */
  private newCode(): string {
    const pick = () =>
      Array.from({ length: GROUP }, () => ALPHABET[randomInt(0, ALPHABET.length)]).join('');
    return `${pick()}-${pick()}`;
  }

  /** Accepts whatever spacing or case she types it back in. */
  private normalize(code: string): string {
    return code.replace(/[\s-]/g, '').toUpperCase();
  }
}
