import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../../prisma/prisma.service';
import { PRIVILEGED_ROLES } from './totp.service';

/**
 * Checks at boot that every privileged account actually holds an authenticator.
 *
 * The rule is enforced when a role is granted, but a rule enforced only at the
 * moment of writing rots: roles get changed by a migration, by a seed, by a
 * direct SQL fix during an incident. This is the pass that notices.
 *
 * In production it refuses to start, because an admin account without a
 * network-independent factor is precisely the account that cannot sign in
 * during a messaging outage — the incident it exists for. In development it
 * logs loudly instead, so a seeded demo database is usable without ceremony.
 */
@Injectable()
export class PrivilegedMfaInvariant implements OnApplicationBootstrap {
  private readonly logger = new Logger(PrivilegedMfaInvariant.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    const offenders = await this.prisma.user.findMany({
      where: {
        role: { in: PRIVILEGED_ROLES },
        disabledAt: null,
        OR: [
          { totpCredential: null },
          { totpCredential: { confirmedAt: null } },
        ],
      },
      select: { id: true, username: true, role: true },
    });

    if (offenders.length === 0) return;

    const summary = offenders
      .map((user) => `${user.username} (${user.role})`)
      .join(', ');
    const message =
      `${offenders.length} privileged account(s) have no confirmed authenticator: ${summary}`;

    if (this.config.get<string>('nodeEnv') === 'production') {
      throw new Error(
        `Refusing to start — ${message}. Enrol them via POST /auth/totp/enroll, ` +
          'or disable the accounts.',
      );
    }

    this.logger.error(message);
    this.logger.error(
      'This would refuse to boot in production. Enrol before deploying.',
    );
  }
}
