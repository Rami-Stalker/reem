import { Injectable, NotFoundException } from '@nestjs/common';
import {
  PolicyAudience,
  PolicyVersionStatus,
  Prisma,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';

/**
 * Reading the policies, and recording who agreed to which.
 *
 * Everything on the reading side is public: a woman deciding whether to make
 * an account has to be able to read the terms of making one, and a policy
 * behind a login is not published. The writing side — `record` — is the only
 * part that needs an account, and it is deliberately idempotent, because the
 * consent screen is exactly the sort of screen somebody taps twice on a bad
 * connection.
 */

/** The locale the platform falls back to. The Arabic text is the binding one. */
export const DEFAULT_POLICY_LOCALE = 'ar';

/** Where an acceptance came from. Recorded so a dispute can be reconstructed. */
export const PolicyConsentSource = {
  Registration: 'registration',
  Reconsent: 'reconsent',
  SellerApplication: 'seller_application',
} as const;

export type PolicyConsentSource =
  (typeof PolicyConsentSource)[keyof typeof PolicyConsentSource];

export interface ConsentContext {
  readonly locale?: string;
  readonly ipAddress?: string;
  readonly userAgent?: string;
}

/**
 * Which audiences a role has to sign for.
 *
 * Staff hold none. An operations administrator is an employee reading a
 * console, not a counterparty to the customer terms, and a consent gate that
 * blocked the admin console until somebody accepted the shopper's terms of use
 * would be a self-inflicted outage the first time legal published a version.
 *
 * A seller signs the seller terms and the commissions she is about to be
 * charged; a customer signs the customer terms. Both sign privacy. Nobody
 * signs a document addressed to the other side of the marketplace.
 */
export function consentAudiencesFor(role: UserRole): PolicyAudience[] {
  switch (role) {
    case UserRole.CUSTOMER:
      return [PolicyAudience.EVERYONE, PolicyAudience.CUSTOMER];
    case UserRole.SELLER:
      return [PolicyAudience.EVERYONE, PolicyAudience.SELLER];
    default:
      return [];
  }
}

/** The published version of each document, with its translations. */
const publishedVersion = {
  where: { status: PolicyVersionStatus.PUBLISHED },
  include: { translations: true },
  take: 1,
} as const;

type DocumentWithPublished = Prisma.PolicyDocumentGetPayload<{
  include: { versions: typeof publishedVersion };
}>;

type Translation = Prisma.PolicyDocumentTranslationGetPayload<object>;

@Injectable()
export class PoliciesService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Reading ─────────────────────────────────────────────────────────────

  /**
   * Every published policy, in one list.
   *
   * `userId` is optional and only decides whether each card can say "you
   * accepted this on …". The list itself is identical for a guest and for a
   * signed-in woman: which policies exist is not private information.
   */
  async catalogue(locale: string | undefined, userId?: string) {
    const documents = await this.prisma.policyDocument.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      include: { versions: publishedVersion },
    });

    const acceptances = userId
      ? await this.acceptancesByDocument(userId)
      : new Map<string, AcceptanceRow>();

    return documents
      .filter((document) => document.versions.length > 0)
      .map((document) =>
        this.summary(document, locale, acceptances.get(document.id)),
      );
  }

  /** One policy, with its text and the trail of issues behind it. */
  async document(slug: string, locale: string | undefined, userId?: string) {
    const document = await this.prisma.policyDocument.findUnique({
      where: { slug },
      include: { versions: publishedVersion },
    });
    if (!document || !document.isActive || document.versions.length === 0) {
      throw new NotFoundException({
        code: 'POLICY_NOT_FOUND',
        message: 'No published policy with that name',
      });
    }

    const acceptance = userId
      ? await this.prisma.policyAcceptance.findFirst({
          where: { userId, documentId: document.id },
          orderBy: { acceptedAt: 'desc' },
          include: { version: { select: { version: true } } },
        })
      : null;

    const current = document.versions[0];
    const translation = this.pick(current.translations, locale);

    // Everything ever published for this document, newest first. Archived
    // versions stay readable on purpose: a woman whose acceptance is recorded
    // against version 2 must be able to see what version 2 said.
    const history = await this.prisma.policyDocumentVersion.findMany({
      where: {
        documentId: document.id,
        status: {
          in: [PolicyVersionStatus.PUBLISHED, PolicyVersionStatus.ARCHIVED],
        },
      },
      orderBy: { version: 'desc' },
      select: {
        id: true,
        version: true,
        status: true,
        publishedAt: true,
        effectiveAt: true,
        changeNote: true,
        requiresReacceptance: true,
      },
    });

    return {
      ...this.summary(document, locale, acceptance ?? undefined),
      body: translation.body,
      content_hash: translation.contentHash,
      available_locales: current.translations
        .map((row) => row.locale)
        .sort((a, b) => a.localeCompare(b)),
      history: history.map((row) => ({
        id: row.id,
        version: row.version,
        status: row.status,
        published_at: row.publishedAt?.toISOString() ?? null,
        effective_at: row.effectiveAt?.toISOString() ?? null,
        change_note: row.changeNote,
        requires_reacceptance: row.requiresReacceptance,
        is_current: row.status === PolicyVersionStatus.PUBLISHED,
      })),
    };
  }

  /**
   * One archived or published issue, by id, so an acceptance can be read back
   * against the text it was made against rather than against today's.
   */
  async version(versionId: string, locale: string | undefined) {
    const version = await this.prisma.policyDocumentVersion.findUnique({
      where: { id: versionId },
      include: { translations: true, document: true },
    });
    if (!version || version.status === PolicyVersionStatus.DRAFT) {
      throw new NotFoundException({
        code: 'POLICY_VERSION_NOT_FOUND',
        message: 'No published policy version with that id',
      });
    }
    const translation = this.pick(version.translations, locale);
    return {
      id: version.id,
      document_id: version.documentId,
      slug: version.document.slug,
      kind: version.document.kind,
      version: version.version,
      status: version.status,
      locale: translation.locale,
      title: translation.title,
      summary: translation.summary,
      body: translation.body,
      content_hash: translation.contentHash,
      change_note: version.changeNote,
      published_at: version.publishedAt?.toISOString() ?? null,
      effective_at: version.effectiveAt?.toISOString() ?? null,
    };
  }

  /**
   * What a new account has to sign, before that account exists.
   *
   * Public, and it has to be: the registration form needs to name the
   * documents and carry their version ids back, and at that point there is no
   * session to authorise the question with.
   */
  async requiredForRole(role: UserRole, locale: string | undefined) {
    const audiences = consentAudiencesFor(role);
    if (audiences.length === 0) return [];

    const documents = await this.prisma.policyDocument.findMany({
      where: {
        isActive: true,
        requiredForConsent: true,
        audience: { in: audiences },
      },
      orderBy: { sortOrder: 'asc' },
      include: { versions: publishedVersion },
    });

    return documents
      .filter((document) => document.versions.length > 0)
      .map((document) => this.summary(document, locale));
  }

  /**
   * What this account still owes a signature on.
   *
   * Two things put a document here, and only two:
   *
   *  - she has **never** accepted it, and it is required for her side of the
   *    marketplace — which is every account that existed before this subsystem
   *    did; or
   *  - the currently published version was published with
   *    `requiresReacceptance`, and her signature is against an older one.
   *
   * A new version published *without* that flag — a typo, a clarification —
   * deliberately does not appear. Interrupting a hundred thousand women to
   * re-sign a comma is how a consent gate becomes something people learn to
   * tap through without reading.
   */
  async pending(userId: string, role: UserRole, locale: string | undefined) {
    const audiences = consentAudiencesFor(role);
    if (audiences.length === 0) return [];

    const documents = await this.prisma.policyDocument.findMany({
      where: {
        isActive: true,
        requiredForConsent: true,
        audience: { in: audiences },
      },
      orderBy: { sortOrder: 'asc' },
      include: { versions: publishedVersion },
    });

    const live = documents.filter((document) => document.versions.length > 0);
    if (live.length === 0) return [];

    const acceptances = await this.prisma.policyAcceptance.findMany({
      where: {
        userId,
        documentId: { in: live.map((document) => document.id) },
      },
      select: { documentId: true, versionId: true },
    });

    const signedVersions = new Set(acceptances.map((row) => row.versionId));
    const signedDocuments = new Set(acceptances.map((row) => row.documentId));

    return live
      .filter((document) => {
        const current = document.versions[0];
        if (signedVersions.has(current.id)) return false;
        if (!signedDocuments.has(document.id)) return true;
        return current.requiresReacceptance;
      })
      .map((document) => this.summary(document, locale));
  }

  /** Her own signatures, newest first — the receipt for every consent given. */
  async acceptances(userId: string, locale: string | undefined) {
    const rows = await this.prisma.policyAcceptance.findMany({
      where: { userId },
      orderBy: { acceptedAt: 'desc' },
      include: {
        document: true,
        version: { include: { translations: true } },
      },
    });

    return rows.map((row) => {
      const translation = this.pick(row.version.translations, locale);
      return {
        id: row.id,
        document_id: row.documentId,
        kind: row.document.kind,
        slug: row.document.slug,
        title: translation.title,
        version_id: row.versionId,
        version: row.version.version,
        locale: row.locale,
        content_hash: row.contentHash,
        source: row.source,
        accepted_at: row.acceptedAt.toISOString(),
        // Whether what she signed is still what the platform publishes. False
        // is not a problem by itself — it only matters when the newer version
        // demanded a re-signature, which `pending` is the answer to.
        is_current: row.version.status === PolicyVersionStatus.PUBLISHED,
      };
    });
  }

  // ── Writing ─────────────────────────────────────────────────────────────

  /**
   * Record a signature against each of [versionIds].
   *
   * Idempotent per (account, version): a second tap writes nothing and answers
   * the same way as the first. Version ids that are not published are ignored
   * rather than refused — a client that sends a stale id after an
   * administrator published a new version should be told what is still
   * outstanding, not handed a 400 it cannot act on.
   *
   * Takes an optional transaction client so registration can write the account
   * and its consent in one go: an account that exists without the consent that
   * created it is exactly the record this subsystem is for.
   */
  async record(
    userId: string,
    versionIds: readonly string[],
    source: PolicyConsentSource,
    context: ConsentContext = {},
    client: Prisma.TransactionClient = this.prisma,
  ): Promise<number> {
    if (versionIds.length === 0) return 0;

    const versions = await client.policyDocumentVersion.findMany({
      where: {
        id: { in: [...new Set(versionIds)] },
        status: PolicyVersionStatus.PUBLISHED,
      },
      include: { translations: true },
    });
    if (versions.length === 0) return 0;

    const locale = this.normaliseLocale(context.locale);

    const rows = versions.map((version) => {
      const translation = this.pick(version.translations, locale);
      return {
        userId,
        documentId: version.documentId,
        versionId: version.id,
        locale: translation.locale,
        contentHash: translation.contentHash,
        source,
        ipAddress: context.ipAddress?.slice(0, 64) ?? null,
        userAgent: context.userAgent?.slice(0, 400) ?? null,
      };
    });

    const written = await client.policyAcceptance.createMany({
      data: rows,
      skipDuplicates: true,
    });
    return written.count;
  }

  /**
   * The published version ids this role must sign, and nothing else.
   *
   * Used by registration and by the seller application to check what came back
   * from the form. Returns an empty list when the policy tables are empty,
   * which is deliberate: a bootstrap that has not run yet must not make it
   * impossible to create an account. The gate is only as strong as the
   * documents that exist, and a platform that cannot be signed up for is worse
   * than one whose first hour of accounts signed nothing.
   */
  async requiredVersionIds(
    role: UserRole,
    client: Prisma.TransactionClient = this.prisma,
  ): Promise<{ documentId: string; versionId: string; slug: string }[]> {
    const audiences = consentAudiencesFor(role);
    if (audiences.length === 0) return [];

    const documents = await client.policyDocument.findMany({
      where: {
        isActive: true,
        requiredForConsent: true,
        audience: { in: audiences },
      },
      select: {
        id: true,
        slug: true,
        versions: {
          where: { status: PolicyVersionStatus.PUBLISHED },
          select: { id: true },
          take: 1,
        },
      },
    });

    return documents
      .filter((document) => document.versions.length > 0)
      .map((document) => ({
        documentId: document.id,
        versionId: document.versions[0].id,
        slug: document.slug,
      }));
  }

  // ── Shaping ─────────────────────────────────────────────────────────────

  private summary(
    document: DocumentWithPublished,
    locale: string | undefined,
    acceptance?: AcceptanceRow,
  ) {
    const current = document.versions[0];
    const translation = this.pick(current.translations, locale);
    const signedCurrent = acceptance?.versionId === current.id;

    return {
      id: document.id,
      kind: document.kind,
      slug: document.slug,
      audience: document.audience,
      icon: document.icon,
      required_for_consent: document.requiredForConsent,
      locale: translation.locale,
      title: translation.title,
      summary: translation.summary,
      version_id: current.id,
      version: current.version,
      change_note: current.changeNote,
      requires_reacceptance: current.requiresReacceptance,
      published_at: current.publishedAt?.toISOString() ?? null,
      effective_at: current.effectiveAt?.toISOString() ?? null,
      acceptance: acceptance
        ? {
            version_id: acceptance.versionId,
            version: acceptance.version.version,
            accepted_at: acceptance.acceptedAt.toISOString(),
            is_current: signedCurrent,
          }
        : null,
    };
  }

  /**
   * The translation for [locale], or the Arabic one, or whatever exists.
   *
   * The last fallback matters more than it looks: an administrator publishing
   * a version with only an English translation would otherwise throw on every
   * read for every Arabic reader, which is a blank policy centre caused by a
   * console mistake. Better to show the language that exists.
   */
  private pick(
    translations: readonly Translation[],
    locale: string | undefined,
  ): Translation {
    const wanted = this.normaliseLocale(locale);
    return (
      translations.find((row) => row.locale === wanted) ??
      translations.find((row) => row.locale === DEFAULT_POLICY_LOCALE) ??
      translations[0]
    );
  }

  /** `ar-SY`, `AR`, `ar` all mean Arabic. Anything unknown means Arabic too. */
  private normaliseLocale(locale: string | undefined): string {
    const base = (locale ?? '').trim().toLowerCase().split(/[-_]/)[0];
    return base === 'en' ? 'en' : DEFAULT_POLICY_LOCALE;
  }

  private async acceptancesByDocument(userId: string) {
    const rows = await this.prisma.policyAcceptance.findMany({
      where: { userId },
      orderBy: { acceptedAt: 'desc' },
      include: { version: { select: { version: true } } },
    });

    // Newest first, so the first row seen for a document is the latest one.
    const latest = new Map<string, AcceptanceRow>();
    for (const row of rows) {
      if (!latest.has(row.documentId)) latest.set(row.documentId, row);
    }
    return latest;
  }
}

type AcceptanceRow = Prisma.PolicyAcceptanceGetPayload<{
  include: { version: { select: { version: true } } };
}>;
