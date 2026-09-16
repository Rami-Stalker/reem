import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PolicyVersionStatus } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { POLICY_SEED } from './policy-content';
import { policyContentHash } from './policy-admin.service';

/**
 * Guarantees the platform always has its policies.
 *
 * Same shape and the same reasoning as `DeliveryProviderBootstrap`: an empty
 * table here is not a cosmetic problem. Registration reads
 * `requiredVersionIds` to decide what a new account must sign, and with no
 * documents it correctly decides "nothing" — so a deploy where somebody forgot
 * to run a seeding script would quietly produce a week of accounts that agreed
 * to nothing, discovered only when a dispute asked what they had agreed to.
 * The demo seeder cannot answer for this either: it is destructive, it is for
 * development, and production never runs it.
 *
 * **It only ever inserts what is missing.** A document that exists is left
 * exactly as it is — including every edit an administrator has published on
 * top of it — because the whole point of the subsystem is that the database,
 * not this file, owns the text after first boot. A missing document is added
 * on its own, so a ninth policy added to `POLICY_SEED` later arrives without
 * touching the eight that are already live.
 */
@Injectable()
export class PolicyBootstrap implements OnModuleInit {
  private readonly logger = new Logger(PolicyBootstrap.name);

  constructor(private readonly prisma: PrismaService) {}

  async onModuleInit(): Promise<void> {
    try {
      await this.ensureSeeded();
    } catch (error) {
      // A boot must not fail because reference content could not be written.
      // The app degrades to "no policies published", which the catalogue, the
      // consent gate and registration all already handle.
      this.logger.warn(
        `Could not verify the policy documents: ${(error as Error).message}`,
      );
    }
  }

  private async ensureSeeded(): Promise<void> {
    const existing = await this.prisma.policyDocument.findMany({
      select: { kind: true },
    });
    const present = new Set(existing.map((row) => row.kind));

    const missing = POLICY_SEED.filter((seed) => !present.has(seed.kind));
    if (missing.length === 0) return;

    const now = new Date();

    for (const seed of missing) {
      await this.prisma.policyDocument.create({
        data: {
          kind: seed.kind,
          slug: seed.slug,
          audience: seed.audience,
          sortOrder: seed.sortOrder,
          requiredForConsent: seed.requiredForConsent,
          icon: seed.icon,
          isActive: true,
          versions: {
            create: {
              version: 1,
              status: PolicyVersionStatus.PUBLISHED,
              // The first issue never demands a re-signature: there is nothing
              // to re-sign against. Accounts that predate the subsystem still
              // meet the gate, because `pending` treats "never signed at all"
              // as outstanding on its own — which is the honest reading, and
              // the one that ends with a consent on file for everybody.
              requiresReacceptance: false,
              effectiveAt: now,
              publishedAt: now,
              changeNote: 'الإصدار الأول',
              translations: {
                create: seed.translations.map((translation) => ({
                  locale: translation.locale,
                  title: translation.title,
                  summary: translation.summary,
                  body: translation.body,
                  contentHash: policyContentHash(translation.body),
                })),
              },
            },
          },
        },
      });
    }

    this.logger.log(
      `Published the first version of ${missing.length} policy document(s): ` +
        missing.map((seed) => seed.slug).join(', '),
    );
  }
}
