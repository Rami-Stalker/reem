import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AccountVerificationKind,
  AccountVerificationStatus,
  AuditSeverity,
  NotificationType,
  Prisma,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../auth/audit.service';
import { MediaService } from '../media/media.service';
import { NotificationsService } from '../notifications/notifications.service';
import { serializePublicUser } from '../../common/serializers';
import {
  AccountVerificationQueryDto,
  ReviewAccountVerificationDto,
  SubmitAccountVerificationDto,
} from './dto/account-verification.dto';

/** The states a woman may move her own claim into. */
const OPEN_STATES: AccountVerificationStatus[] = [
  AccountVerificationStatus.PENDING,
  AccountVerificationStatus.UNDER_REVIEW,
  AccountVerificationStatus.NEEDS_MORE_INFO,
];

/**
 * How long a refusal stands before she may ask again.
 *
 * Not punishment — a queue. A rejected claim resubmitted the same afternoon
 * with the same unreadable photograph costs a reviewer the same minute twice,
 * and the woman who is waiting behind it pays for it.
 */
const REAPPLY_AFTER_DAYS = 14;

const withUser = {
  user: true,
  history: { orderBy: { createdAt: 'desc' as const }, take: 20 },
} satisfies Prisma.AccountVerificationInclude;

type VerificationRecord = Prisma.AccountVerificationGetPayload<{
  include: typeof withUser;
}>;

/**
 * Account verification — the thing behind «موثّقة».
 *
 * **What was here before.** Nothing. The badge on a name was
 * `users.is_verified`, and `users.is_verified` was set to `true` by the OTP
 * exchange: registration, a sign-in code, a phone change and account recovery
 * all wrote it. Every account that had ever received a text message wore the
 * badge, so it appeared next to a brand-new account and next to a reviewed
 * boutique identically and meant nothing in either place. There was no way to
 * apply for it, no reviewer, no evidence, no record, and no way to take it
 * away.
 *
 * **What is here now.** A claim she files with documents, a reviewer who
 * decides and must give a reason, a status she can read and act on, an
 * append-only history, an audit entry per decision, and a badge written in
 * exactly one method — {@link decide}. Nothing else in this codebase writes
 * `users.is_verified` any more, and the migration beside this file withdrew
 * every badge that the OTP path had handed out.
 *
 * **Why the documents are not in any public serializer.** They are
 * photographs of a woman's identity card. {@link serializeForOwner} and
 * {@link serializeForStaff} are the only two shapes that carry them; the
 * public one carries a boolean and a date.
 */
@Injectable()
export class AccountVerificationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly media: MediaService,
    private readonly notifications: NotificationsService,
  ) {}

  // ── Hers ─────────────────────────────────────────────────────────────────

  /** Her claim, or null when she has never filed one. */
  async mine(userId: string) {
    const record = await this.prisma.accountVerification.findUnique({
      where: { userId },
      include: withUser,
    });
    return record ? this.serializeForOwner(record) : null;
  }

  /**
   * Files a claim, or amends the open one.
   *
   * Amending rather than filing again is the whole reason the row is unique
   * per account: a woman told «الصورة مو واضحة» sends a clearer photograph,
   * and that has to reach the reviewer who asked rather than join the back of
   * the queue as a second application nobody connects to the first.
   */
  async submit(userId: string, dto: SubmitAccountVerificationDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, phoneVerifiedAt: true },
    });
    if (!user) throw new NotFoundException('Account not found');

    // The number first. A badge is a claim about *who this is*, and the
    // cheapest thing that ties an account to a person is the SIM it signs in
    // with — reviewing documents for an account that has not even done that is
    // reviewing documents for nobody.
    if (!user.phoneVerifiedAt) {
      throw new BadRequestException({
        code: 'PHONE_NOT_VERIFIED',
        message: 'Verify your phone number before applying',
      });
    }

    const existing = await this.prisma.accountVerification.findUnique({
      where: { userId },
    });

    if (existing?.status === AccountVerificationStatus.APPROVED) {
      throw new BadRequestException({
        code: 'ALREADY_VERIFIED',
        message: 'This account is already verified',
      });
    }
    if (
      existing?.status === AccountVerificationStatus.REJECTED ||
      existing?.status === AccountVerificationStatus.REVOKED
    ) {
      const waitUntil = new Date(existing.reviewedAt ?? existing.updatedAt);
      waitUntil.setDate(waitUntil.getDate() + REAPPLY_AFTER_DAYS);
      if (waitUntil > new Date()) {
        throw new BadRequestException({
          code: 'REAPPLY_TOO_SOON',
          message: `You may apply again after ${waitUntil.toISOString()}`,
        });
      }
    }

    const kind =
      dto.kind ??
      (user.role === UserRole.SELLER
        ? AccountVerificationKind.BUSINESS
        : AccountVerificationKind.PERSONAL);

    const data = {
      kind,
      legalName: dto.legal_name.trim(),
      documentType: dto.document_type?.trim() || null,
      documentFrontUrl: dto.document_front_url?.trim() || null,
      documentBackUrl: dto.document_back_url?.trim() || null,
      selfieUrl: dto.selfie_url?.trim() || null,
      supportingUrls: (dto.supporting_urls ?? []) as Prisma.InputJsonValue,
      note: dto.note?.trim() || null,
      // Back to the queue, and the reviewer's last note is cleared: it
      // described the submission she has just replaced.
      status: AccountVerificationStatus.PENDING,
      reviewNote: null,
      reviewedBy: null,
      reviewedAt: null,
      submittedAt: new Date(),
    };

    const record = await this.prisma.accountVerification.upsert({
      where: { userId },
      create: { userId, ...data },
      update: data,
      include: withUser,
    });

    await this.prisma.accountVerificationStatusEvent.create({
      data: {
        verificationId: record.id,
        status: AccountVerificationStatus.PENDING,
        reason: existing ? 'Resubmitted by the account' : 'Submitted',
        // Null actor: she moved it herself. A reviewer's id here would make
        // the history read as though staff filed her application.
        actorId: null,
      },
    });

    // The uploads now belong to a record, so the orphan sweeper leaves them.
    await this.media.markAttached(
      userId,
      [
        data.documentFrontUrl,
        data.documentBackUrl,
        data.selfieUrl,
        ...(dto.supporting_urls ?? []),
      ].filter((url): url is string => !!url),
    );

    return this.serializeForOwner(record);
  }

  /** Withdraws an open claim. The documents go with it. */
  async withdraw(userId: string) {
    const record = await this.prisma.accountVerification.findUnique({
      where: { userId },
    });
    if (!record) throw new NotFoundException('No application to withdraw');
    if (!OPEN_STATES.includes(record.status)) {
      throw new BadRequestException('This application is already decided');
    }
    await this.prisma.accountVerification.delete({ where: { userId } });
    return { message: 'Application withdrawn' };
  }

  // ── Staff ────────────────────────────────────────────────────────────────

  /** The review queue. */
  async list(query: AccountVerificationQueryDto = {}) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const where: Prisma.AccountVerificationWhereInput = {
      ...(query.status ? { status: query.status } : {}),
      ...(query.q
        ? {
            OR: [
              { legalName: { contains: query.q, mode: 'insensitive' } },
              { user: { name: { contains: query.q, mode: 'insensitive' } } },
              {
                user: { username: { contains: query.q, mode: 'insensitive' } },
              },
            ],
          }
        : {}),
    };

    const [rows, total, pending] = await Promise.all([
      this.prisma.accountVerification.findMany({
        where,
        // Oldest first: a queue that shows the newest application at the top
        // is a queue where the woman who has waited longest waits for ever.
        orderBy: { submittedAt: 'asc' },
        skip: (page - 1) * limit,
        take: limit,
        include: withUser,
      }),
      this.prisma.accountVerification.count({ where }),
      this.prisma.accountVerification.count({
        where: { status: AccountVerificationStatus.PENDING },
      }),
    ]);

    return {
      items: rows.map((row) => this.serializeForStaff(row)),
      page,
      limit,
      total,
      has_more: page * limit < total,
      pending,
    };
  }

  async detail(id: string) {
    const record = await this.prisma.accountVerification.findUnique({
      where: { id },
      include: withUser,
    });
    if (!record) throw new NotFoundException('Application not found');
    return this.serializeForStaff(record);
  }

  /**
   * **The one place `users.is_verified` is written.**
   *
   * Granting and withdrawing the badge, the status, the history entry and the
   * audit trail move together inside one transaction, because a badge granted
   * without a record of who granted it is exactly the state this whole module
   * exists to make impossible.
   */
  async decide(
    actorId: string,
    id: string,
    dto: ReviewAccountVerificationDto,
  ) {
    const record = await this.prisma.accountVerification.findUnique({
      where: { id },
      select: { id: true, userId: true, status: true },
    });
    if (!record) throw new NotFoundException('Application not found');
    if (record.status === dto.status) {
      throw new BadRequestException('The application is already in that state');
    }
    if (dto.status === AccountVerificationStatus.PENDING) {
      throw new ForbiddenException(
        'Only the account may return an application to the queue',
      );
    }

    const approving = dto.status === AccountVerificationStatus.APPROVED;
    const withdrawing =
      dto.status === AccountVerificationStatus.REJECTED ||
      dto.status === AccountVerificationStatus.REVOKED;
    const now = new Date();

    const updated = await this.prisma.$transaction(async (tx) => {
      const verification = await tx.accountVerification.update({
        where: { id },
        data: {
          status: dto.status,
          reviewNote: dto.reason.trim(),
          reviewedBy: actorId,
          reviewedAt: now,
        },
        include: withUser,
      });

      // The badge itself. Only approval grants it; a refusal or a revocation
      // takes it away, and «نحتاج توضيح» leaves whatever she has alone,
      // because it is a question rather than a decision.
      if (approving || withdrawing) {
        await tx.user.update({
          where: { id: record.userId },
          data: {
            isVerified: approving,
            verifiedAt: approving ? now : null,
          },
        });
      }

      await tx.accountVerificationStatusEvent.create({
        data: {
          verificationId: id,
          status: dto.status,
          reason: dto.reason.trim(),
          actorId,
        },
      });

      return verification;
    });

    await this.audit.record({
      actorId,
      action: 'account_verification_decided',
      category: 'verification',
      outcome: 'success',
      severity: approving ? AuditSeverity.INFO : AuditSeverity.WARNING,
      metadata: {
        verification_id: id,
        subject_id: record.userId,
        status_from: record.status,
        status_to: dto.status,
        reason: dto.reason.trim(),
      },
    });

    await this.notifySubject(record.userId, dto);

    return this.serializeForStaff(updated);
  }

  // ── Internals ────────────────────────────────────────────────────────────

  /** She is told what happened, and what it means she can do next. */
  private async notifySubject(
    userId: string,
    dto: ReviewAccountVerificationDto,
  ) {
    const copy = {
      [AccountVerificationStatus.APPROVED]: {
        title: 'تم توثيق حسابك',
        body: 'صار في علامة توثيق جنب اسمك.',
      },
      [AccountVerificationStatus.NEEDS_MORE_INFO]: {
        title: 'منحتاج توضيح على طلب التوثيق',
        body: dto.reason.trim(),
      },
      [AccountVerificationStatus.REJECTED]: {
        title: 'ما قدرنا نوثّق حسابك',
        body: dto.reason.trim(),
      },
      [AccountVerificationStatus.REVOKED]: {
        title: 'تم سحب توثيق حسابك',
        body: dto.reason.trim(),
      },
      [AccountVerificationStatus.UNDER_REVIEW]: {
        title: 'طلب التوثيق قيد المراجعة',
        body: 'عم نراجع أوراقك، وبنرجعلك بالنتيجة.',
      },
    }[dto.status as Exclude<AccountVerificationStatus, 'PENDING'>];
    if (!copy) return;

    try {
      await this.notifications.notifyAccount({
        userId,
        type: NotificationType.system,
        title: copy.title,
        body: copy.body,
        // Opens the screen that shows the reviewer's note, which is the only
        // reason «نحتاج توضيح» is worth pushing at all.
        data: { deep_link: 'reem://account-verification' },
      });
    } catch {
      // A decision must not fail because a push did. She sees the status on
      // the screen either way.
    }
  }

  /**
   * What she sees of her own claim — her documents included, because they are
   * hers and she has to be able to check what she sent.
   */
  private serializeForOwner(record: VerificationRecord) {
    return {
      id: record.id,
      status: record.status.toLowerCase(),
      kind: record.kind.toLowerCase(),
      legal_name: record.legalName,
      document_type: record.documentType,
      document_front_url: record.documentFrontUrl,
      document_back_url: record.documentBackUrl,
      selfie_url: record.selfieUrl,
      supporting_urls: record.supportingUrls ?? [],
      note: record.note,
      // The reviewer's words reach her: that is what makes «نحتاج توضيح» an
      // instruction rather than a dead end.
      review_note: record.reviewNote,
      submitted_at: record.submittedAt.toISOString(),
      reviewed_at: record.reviewedAt?.toISOString() ?? null,
      can_resubmit: this.canResubmit(record),
      history: record.history.map((event) => ({
        status: event.status.toLowerCase(),
        reason: event.reason,
        created_at: event.createdAt.toISOString(),
      })),
    };
  }

  /** The reviewer's shape: hers, plus who is asking. */
  private serializeForStaff(record: VerificationRecord) {
    return {
      ...this.serializeForOwner(record),
      user: serializePublicUser(record.user),
      user_id: record.userId,
      reviewed_by: record.reviewedBy,
    };
  }

  private canResubmit(record: VerificationRecord): boolean {
    if (record.status === AccountVerificationStatus.APPROVED) return false;
    if (record.status === AccountVerificationStatus.NEEDS_MORE_INFO) return true;
    if (OPEN_STATES.includes(record.status)) return false;
    const waitUntil = new Date(record.reviewedAt ?? record.updatedAt);
    waitUntil.setDate(waitUntil.getDate() + REAPPLY_AFTER_DAYS);
    return waitUntil <= new Date();
  }
}
