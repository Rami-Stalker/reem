import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PolicyVersionStatus, Prisma } from '@prisma/client';
import { createHash } from 'node:crypto';

import { PrismaService } from '../../prisma/prisma.service';
import {
  CreatePolicyVersionDto,
  PolicyTranslationDto,
  PublishPolicyVersionDto,
  UpdatePolicyDocumentDto,
  UpdatePolicyVersionDto,
} from './dto/policy-admin.dto';

/**
 * Editing and publishing the policies from the console.
 *
 * Three rules hold the whole thing together, and all three are enforced here
 * rather than trusted to a careful operator:
 *
 *  1. **A published version is immutable.** Every write refuses anything that
 *     is not a draft. This is what makes an acceptance mean something: the
 *     text a woman agreed to cannot be edited out from under her signature.
 *  2. **One draft at a time, per document.** Two people editing two drafts of
 *     the terms of use and each publishing theirs is how a clause silently
 *     reverts.
 *  3. **Exactly one published version per document.** Publishing archives its
 *     predecessor in the same transaction, so there is no instant in which a
 *     policy has two current texts or none.
 *
 * Every route that reaches this service is a staff write, so it is recorded by
 * `AdminAuditInterceptor` without this file doing anything: the actor, the
 * route, the document id and the outcome. The bodies are not recorded, which
 * is right — they are already versioned rows, and the audit trail is not a
 * second copy of the terms of use.
 */
@Injectable()
export class PolicyAdminService {
  constructor(private readonly prisma: PrismaService) {}

  /** Every document with every version — the console's whole working set. */
  async documents() {
    const documents = await this.prisma.policyDocument.findMany({
      orderBy: { sortOrder: 'asc' },
      include: {
        versions: {
          orderBy: { version: 'desc' },
          include: { translations: true },
        },
        _count: { select: { acceptances: true } },
      },
    });

    return documents.map((document) => ({
      id: document.id,
      kind: document.kind,
      slug: document.slug,
      audience: document.audience,
      sort_order: document.sortOrder,
      required_for_consent: document.requiredForConsent,
      is_active: document.isActive,
      icon: document.icon,
      acceptance_count: document._count.acceptances,
      versions: document.versions.map((version) => ({
        id: version.id,
        version: version.version,
        status: version.status,
        requires_reacceptance: version.requiresReacceptance,
        change_note: version.changeNote,
        published_at: version.publishedAt?.toISOString() ?? null,
        effective_at: version.effectiveAt?.toISOString() ?? null,
        created_at: version.createdAt.toISOString(),
        updated_at: version.updatedAt.toISOString(),
        translations: version.translations.map((translation) => ({
          locale: translation.locale,
          title: translation.title,
          summary: translation.summary,
          body: translation.body,
          content_hash: translation.contentHash,
        })),
      })),
    }));
  }

  /** The switches around a document. Never its text. */
  async updateDocument(id: string, dto: UpdatePolicyDocumentDto) {
    await this.documentOrThrow(id);

    await this.prisma.policyDocument.update({
      where: { id },
      data: {
        audience: dto.audience,
        sortOrder: dto.sort_order,
        requiredForConsent: dto.required_for_consent,
        isActive: dto.is_active,
        icon: dto.icon,
      },
    });

    return this.documents();
  }

  /**
   * Open a draft on top of the published version.
   *
   * Cloning by default is the difference between "amend clause 4" and "retype
   * the terms of use", and the second is where clauses go missing.
   */
  async createVersion(
    documentId: string,
    dto: CreatePolicyVersionDto,
    actorId: string,
  ) {
    const document = await this.documentOrThrow(documentId);

    const existingDraft = document.versions.find(
      (version) => version.status === PolicyVersionStatus.DRAFT,
    );
    if (existingDraft) {
      throw new ConflictException({
        code: 'POLICY_DRAFT_EXISTS',
        message:
          'This policy already has an open draft. Publish or discard it first.',
      });
    }

    const published = document.versions.find(
      (version) => version.status === PolicyVersionStatus.PUBLISHED,
    );
    const source: PolicyTranslationDto[] =
      dto.translations?.length
        ? dto.translations
        : (published?.translations ?? []).map((translation) => ({
            locale: translation.locale,
            title: translation.title,
            summary: translation.summary ?? undefined,
            body: translation.body,
          }));

    if (source.length === 0) {
      throw new BadRequestException({
        code: 'POLICY_TRANSLATIONS_REQUIRED',
        message:
          'There is no published version to copy, so the draft needs its own text',
      });
    }

    this.assertDistinctLocales(source);

    const nextVersion =
      document.versions.reduce(
        (highest, version) => Math.max(highest, version.version),
        0,
      ) + 1;

    await this.prisma.policyDocumentVersion.create({
      data: {
        documentId,
        version: nextVersion,
        status: PolicyVersionStatus.DRAFT,
        changeNote: dto.change_note,
        createdById: actorId,
        translations: { create: source.map((row) => this.translationRow(row)) },
      },
    });

    return this.documents();
  }

  /** Edit a draft. Anything published refuses — see the class doc. */
  async updateVersion(versionId: string, dto: UpdatePolicyVersionDto) {
    const version = await this.draftOrThrow(versionId);

    if (dto.translations?.length) {
      this.assertDistinctLocales(dto.translations);
    }

    await this.prisma.$transaction(async (tx) => {
      if (dto.translations?.length) {
        // Replaced wholesale rather than merged: an editor who removes the
        // English translation from the console means to remove it, and a merge
        // would leave the old one published beside a body it no longer matches.
        await tx.policyDocumentTranslation.deleteMany({
          where: { versionId },
        });
        await tx.policyDocumentTranslation.createMany({
          data: dto.translations.map((row) => ({
            versionId,
            ...this.translationRow(row),
          })),
        });
      }

      await tx.policyDocumentVersion.update({
        where: { id: version.id },
        data: { changeNote: dto.change_note ?? version.changeNote },
      });
    });

    return this.documents();
  }

  /**
   * Publish a draft: it becomes current, its predecessor is archived, and both
   * happen in one transaction so no reader ever sees a document with two
   * current texts or with none.
   */
  async publishVersion(
    versionId: string,
    dto: PublishPolicyVersionDto,
    actorId: string,
  ) {
    const version = await this.draftOrThrow(versionId);

    const translations = await this.prisma.policyDocumentTranslation.findMany({
      where: { versionId },
    });
    if (translations.length === 0) {
      throw new BadRequestException({
        code: 'POLICY_TRANSLATIONS_REQUIRED',
        message: 'A version with no text cannot be published',
      });
    }

    const now = new Date();
    const effectiveAt = dto.effective_at ? new Date(dto.effective_at) : now;

    await this.prisma.$transaction(async (tx) => {
      await tx.policyDocumentVersion.updateMany({
        where: {
          documentId: version.documentId,
          status: PolicyVersionStatus.PUBLISHED,
        },
        data: { status: PolicyVersionStatus.ARCHIVED },
      });

      await tx.policyDocumentVersion.update({
        where: { id: versionId },
        data: {
          status: PolicyVersionStatus.PUBLISHED,
          requiresReacceptance: dto.requires_reacceptance,
          effectiveAt,
          publishedAt: now,
          publishedById: actorId,
          changeNote: dto.change_note ?? version.changeNote,
        },
      });
    });

    return this.documents();
  }

  /**
   * Throw a draft away.
   *
   * Only ever a draft: an archived version is somebody's evidence of what she
   * agreed to, and a published one is the live contract.
   */
  async discardVersion(versionId: string) {
    await this.draftOrThrow(versionId);
    await this.prisma.policyDocumentVersion.delete({ where: { id: versionId } });
    return this.documents();
  }

  /**
   * How many accounts have signed the current version of each document, and
   * how many are still outstanding on a version that demanded re-signature.
   *
   * The number the console actually needs after publishing a material change:
   * "is this landing, or has nobody opened the app since".
   */
  async consentSummary() {
    const documents = await this.prisma.policyDocument.findMany({
      where: { isActive: true, requiredForConsent: true },
      orderBy: { sortOrder: 'asc' },
      include: {
        versions: {
          where: { status: PolicyVersionStatus.PUBLISHED },
          select: { id: true, version: true, requiresReacceptance: true },
          take: 1,
        },
      },
    });

    const rows = [];
    for (const document of documents) {
      const current = document.versions[0];
      if (!current) continue;

      const [onCurrent, onAnything] = await Promise.all([
        this.prisma.policyAcceptance.count({
          where: { versionId: current.id },
        }),
        this.prisma.policyAcceptance
          .findMany({
            where: { documentId: document.id },
            distinct: ['userId'],
            select: { userId: true },
          })
          .then((accounts) => accounts.length),
      ]);

      rows.push({
        document_id: document.id,
        slug: document.slug,
        kind: document.kind,
        audience: document.audience,
        version: current.version,
        requires_reacceptance: current.requiresReacceptance,
        accepted_current: onCurrent,
        accepted_any_version: onAnything,
      });
    }
    return rows;
  }

  // ── Guards and helpers ──────────────────────────────────────────────────

  private async documentOrThrow(id: string) {
    const document = await this.prisma.policyDocument.findUnique({
      where: { id },
      include: { versions: { include: { translations: true } } },
    });
    if (!document) {
      throw new NotFoundException({
        code: 'POLICY_NOT_FOUND',
        message: 'No policy document with that id',
      });
    }
    return document;
  }

  /**
   * The single place "published versions are frozen" is enforced.
   *
   * A 409 rather than a 404 when the version exists but is published: the
   * editor needs to be told she is looking at a live contract, not that her id
   * was wrong.
   */
  private async draftOrThrow(versionId: string) {
    const version = await this.prisma.policyDocumentVersion.findUnique({
      where: { id: versionId },
    });
    if (!version) {
      throw new NotFoundException({
        code: 'POLICY_VERSION_NOT_FOUND',
        message: 'No policy version with that id',
      });
    }
    if (version.status !== PolicyVersionStatus.DRAFT) {
      throw new ConflictException({
        code: 'POLICY_VERSION_NOT_EDITABLE',
        message:
          'A published or archived version cannot be changed. Open a new draft instead.',
      });
    }
    return version;
  }

  private assertDistinctLocales(translations: readonly PolicyTranslationDto[]) {
    const locales = translations.map((row) => row.locale.trim().toLowerCase());
    if (new Set(locales).size !== locales.length) {
      throw new BadRequestException({
        code: 'POLICY_DUPLICATE_LOCALE',
        message: 'Each language may appear once per version',
      });
    }
  }

  private translationRow(
    row: PolicyTranslationDto,
  ): Prisma.PolicyDocumentTranslationCreateWithoutVersionInput {
    const body = row.body;
    return {
      locale: row.locale.trim().toLowerCase(),
      title: row.title.trim(),
      summary: row.summary?.trim() || null,
      body,
      contentHash: policyContentHash(body),
    };
  }
}

/**
 * The fingerprint an acceptance carries.
 *
 * Over the body alone, normalised for line endings: the same text pasted from
 * a Windows console and from a Mac one is the same policy, and a hash that
 * disagreed about that would raise a tamper flag on a copy-and-paste.
 */
export function policyContentHash(body: string): string {
  return createHash('sha256')
    .update(body.replace(/\r\n/g, '\n'), 'utf8')
    .digest('hex');
}
