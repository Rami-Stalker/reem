import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  AccountRecoveryStatus,
  AuditSeverity,
  NotificationType,
  OtpPurpose,
  Prisma,
  RiskLevel,
  SecurityEventType,
  SessionStatus,
  User,
  UserRole,
} from '@prisma/client';
import { createHmac, randomBytes, timingSafeEqual } from 'crypto';
import { PrismaService } from '../../../prisma/prisma.service';
import { OtpService } from '../otp.service';
import { maskDestination } from '../otp/otp-transport';
import { RequestContext } from '../interfaces/request-context.interface';
import { AuditService } from '../audit.service';
import { SubmitRecoveryCaseDto } from '../dto/account-recovery.dto';

/**
 * Seventy-two hours between the second approval and the hand-over.
 *
 * The delay is the control, not the paperwork before it. In every scenario
 * except the one this path exists for, the woman who owns the account is still
 * holding her SIM and still has the app — so she is told the moment the case is
 * approved and can kill it with one tap. An attacker cannot compress three
 * days, and three days is far longer than it takes someone to notice a message
 * saying her account is about to be handed to somebody else.
 */
const COOL_OFF_MS = 72 * 60 * 60_000;

/** A case that nobody has progressed in a fortnight is abandoned. */
const CASE_TTL_MS = 14 * 24 * 60 * 60_000;

/** See `PhoneChangeService` — same reasoning, same week. */
const PAYOUT_FREEZE_MS = 7 * 24 * 60 * 60_000;

/**
 * Below this, a case is not worth a reviewer's time and says so in the queue.
 * Advisory only: a low score orders the queue, it never decides anything, and
 * a high one confers nothing without two humans and three days.
 */
const REVIEWABLE_SCORE = 40;

const PRIVILEGED_ROLES: UserRole[] = [
  UserRole.SUPER_ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.SUPPORT_ADMIN,
  UserRole.FINANCE_ADMIN,
  UserRole.CONTENT_MODERATOR,
  UserRole.ADMIN,
  UserRole.SUPPORT,
];

interface EvidenceCheck {
  key: string;
  weight: number;
  matched: boolean;
  answered: boolean;
}

/**
 * Support-mediated account recovery.
 *
 * This is the last door in the system, and it exists for exactly one situation
 * that nothing else can reach: the SIM is gone, there is no recovery code and
 * no authenticator. Every other lost-access story has a self-service answer,
 * and should be pushed towards one.
 *
 * Owner decision 4 fixes what may be asked for: **platform-held data only**.
 * No selfies, no photographs of identity documents. That is not squeamishness.
 * A support queue full of face photographs of women on a women-only platform in
 * Syria is a liability whose worst outcome is not financial — and the documents
 * would not even answer the question, because they prove who is holding a phone
 * today, not who opened the account.
 *
 * What carries the weight instead is structural, and an attacker has to beat
 * all four parts at once:
 *
 *  1. **Knowledge only the platform holds** — what she bought, when, from whom,
 *     what her devices are called. Scored automatically, never disclosed.
 *  2. **Dual control** — two distinct staff accounts must approve. One phished
 *     or bribed support login is not enough to hand over an account.
 *  3. **A 72-hour cool-off** — during which the number on file is told, and can
 *     cancel.
 *  4. **A 7-day payout freeze** afterwards — so even a successful takeover
 *     cannot convert into money before the owner reacts.
 *
 * Privileged accounts are refused outright. Recovering an admin account through
 * a support queue is the single highest-value attack against the platform, and
 * no amount of process makes that path worth having.
 */
@Injectable()
export class AccountRecoveryService {
  private readonly logger = new Logger(AccountRecoveryService.name);
  private readonly pepper: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly otp: OtpService,
    private readonly audit: AuditService,
    config: ConfigService,
  ) {
    this.pepper = config.get<string>('security.otpPepper') as string;
  }

  // ─────────────────────────── Claimant side ───────────────────────────

  /**
   * Opens a case.
   *
   * The response is byte-identical whether the claimed number has an account,
   * has a *privileged* account, or has never been seen. This route is
   * unauthenticated by necessity — she cannot sign in, that is the whole
   * premise — which makes any variation in the answer a free oracle for asking
   * whether a given woman is on Ohara.
   */
  async submit(dto: SubmitRecoveryCaseDto, context: RequestContext) {
    // The contact number is verified first, so the queue only ever contains
    // cases from someone who is at least reachable.
    await this.otp.consumeAny(
      dto.contact_phone,
      OtpPurpose.ACCOUNT_RECOVERY,
      dto.contact_code,
    );

    const user = await this.prisma.user.findUnique({
      where: { phone: dto.claimed_phone },
      include: {
        orders: { orderBy: { createdAt: 'desc' }, take: 1 },
        deviceKeys: { where: { revokedAt: null }, take: 20 },
        devices: { take: 20 },
      },
    });

    const privileged = user ? PRIVILEGED_ROLES.includes(user.role) : false;
    const checks = user ? this.scoreEvidence(dto, user) : [];
    const score = checks.reduce(
      (total, check) => total + (check.matched ? check.weight : 0),
      0,
    );

    const claimSecret = randomBytes(32).toString('base64url');
    const now = new Date();

    const recoveryCase = await this.prisma.accountRecoveryCase.create({
      data: {
        // Null for an unknown number: the case is still written, so the rate
        // limiter and the abuse report see the attempt.
        userId: privileged ? null : (user?.id ?? null),
        claimedPhone: dto.claimed_phone,
        contactPhone: dto.contact_phone,
        newPhone: dto.contact_phone,
        // A privileged claim is filed already refused. It is never queued, and
        // the claimant is told the same thing everybody else is told.
        status: privileged
          ? AccountRecoveryStatus.REJECTED
          : AccountRecoveryStatus.SUBMITTED,
        rejectedAt: privileged ? now : null,
        rejectedReason: privileged
          ? 'privileged_account_out_of_band'
          : null,
        // What matched, never what she typed. The case file must not become a
        // second copy of her order history sitting in a support tool.
        evidence: this.json({
          checks: checks.map((check) => ({
            key: check.key,
            answered: check.answered,
            matched: check.matched,
            weight: check.weight,
          })),
          account_exists: user !== null,
        }),
        score,
        riskNotes: this.riskNotesFor(user, score, privileged),
        claimSecretHash: this.digest(claimSecret),
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        expiresAt: new Date(now.getTime() + CASE_TTL_MS),
      },
    });

    await this.prisma.accountRecoveryEvent.create({
      data: {
        caseId: recoveryCase.id,
        action: 'submitted',
        metadata: this.json({ score, privileged }),
      },
    });

    if (user && !privileged) {
      await this.prisma.securityEvent.create({
        data: {
          actorId: user.id,
          type: SecurityEventType.RECOVERY_CASE_OPENED,
          riskLevel: RiskLevel.HIGH,
          ipAddress: context.ipAddress,
          userAgent: context.userAgent,
          resource: `recovery_case:${recoveryCase.id}`,
          metadata: { score },
        },
      });
      // She still holds the SIM in every scenario but the real one, so tell
      // her now rather than at approval — the earlier she can say "that is not
      // me", the less of a reviewer's day the attacker wastes.
      await this.notifyOwner(
        user.id,
        'طلب استعادة حساب',
        'تلقّينا طلبًا لاستعادة حسابكِ من رقم آخر. إن لم تكوني أنت، تجاهلي هذه الرسالة ولن يتغيّر شيء — ويمكنك إلغاء الطلب من إعدادات الأمان.',
        { action: 'recovery_case_opened', case_id: recoveryCase.id },
      );
    }

    await this.audit.record({
      action: 'recovery_case_submitted',
      category: 'auth',
      outcome: 'success',
      severity: AuditSeverity.WARNING,
      context,
      metadata: { case_id: recoveryCase.id, score },
    });

    // Identical for every caller.
    return {
      case_id: recoveryCase.id,
      claim_secret: claimSecret,
      status: 'submitted',
      message:
        'استلمنا طلبكِ. سنراجعه يدويًا، وقد تستغرق المراجعة عدة أيام. سنتواصل معكِ على الرقم الذي أدخلتِه.',
    };
  }

  /**
   * Status for the claimant, against the secret handed out at submission.
   *
   * Deliberately coarse. It never says why a case was refused, never confirms
   * the account exists, and never names the reviewer.
   */
  async claimantStatus(caseId: string, claimSecret: string) {
    const recoveryCase = await this.prisma.accountRecoveryCase.findUnique({
      where: { id: caseId },
    });
    if (
      !recoveryCase?.claimSecretHash ||
      !this.secretMatches(claimSecret, recoveryCase.claimSecretHash)
    ) {
      throw new NotFoundException('No such recovery case');
    }

    return {
      case_id: recoveryCase.id,
      status: recoveryCase.status.toLowerCase(),
      // The only forward-looking fact worth giving her: when it can finish.
      completes_at: recoveryCase.coolOffUntil?.toISOString() ?? null,
      submitted_at: recoveryCase.createdAt.toISOString(),
    };
  }

  /**
   * The owner, from a live session, stopping a case.
   *
   * This is the control the entire cool-off is built around, so it is
   * deliberately the cheapest action in the flow: no step-up, no device proof.
   * Anyone holding a live session on the account is either the owner or an
   * attacker who already has what recovery would give them.
   */
  async cancelByOwner(userId: string, caseId: string, context: RequestContext) {
    const recoveryCase = await this.prisma.accountRecoveryCase.findFirst({
      where: { id: caseId, userId },
    });
    if (!recoveryCase) throw new NotFoundException('No such recovery case');
    if (!this.isLive(recoveryCase.status)) {
      throw new BadRequestException({
        code: 'RECOVERY_CASE_CLOSED',
        message: 'That recovery request is already closed',
      });
    }

    await this.transition(
      recoveryCase.id,
      AccountRecoveryStatus.CANCELLED,
      { cancelledAt: new Date() },
      { actorId: userId, action: 'cancelled', note: 'cancelled_by_owner' },
    );

    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        type: SecurityEventType.RECOVERY_CASE_CANCELLED,
        riskLevel: RiskLevel.HIGH,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        resource: `recovery_case:${caseId}`,
      },
    });
    await this.audit.record({
      actorId: userId,
      action: 'recovery_case_cancelled',
      category: 'auth',
      outcome: 'success',
      severity: AuditSeverity.CRITICAL,
      context,
      metadata: { case_id: caseId },
    });

    return { case_id: caseId, status: 'cancelled' };
  }

  /** Cases the signed-in owner should be shown, so the app can warn her. */
  async openCasesFor(userId: string) {
    const cases = await this.prisma.accountRecoveryCase.findMany({
      where: {
        userId,
        status: {
          in: [
            AccountRecoveryStatus.SUBMITTED,
            AccountRecoveryStatus.UNDER_REVIEW,
            AccountRecoveryStatus.AWAITING_SECOND_APPROVAL,
            AccountRecoveryStatus.COOLING_OFF,
          ],
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return cases.map((item) => ({
      case_id: item.id,
      status: item.status.toLowerCase(),
      opened_at: item.createdAt.toISOString(),
      completes_at: item.coolOffUntil?.toISOString() ?? null,
      contact_phone: maskDestination(item.contactPhone),
    }));
  }

  // ───────────────────────────── Staff side ─────────────────────────────

  async list(params: {
    status?: AccountRecoveryStatus;
    take?: number;
    skip?: number;
  }) {
    const take = Math.min(params.take ?? 25, 100);
    const [items, total] = await Promise.all([
      this.prisma.accountRecoveryCase.findMany({
        where: params.status ? { status: params.status } : {},
        orderBy: [{ score: 'desc' }, { createdAt: 'asc' }],
        take,
        skip: params.skip ?? 0,
      }),
      this.prisma.accountRecoveryCase.count({
        where: params.status ? { status: params.status } : {},
      }),
    ]);
    return {
      items: items.map((item) => this.staffSummary(item)),
      total,
    };
  }

  async detail(caseId: string) {
    const recoveryCase = await this.prisma.accountRecoveryCase.findUnique({
      where: { id: caseId },
      include: {
        events: { orderBy: { createdAt: 'asc' } },
        user: {
          select: {
            id: true,
            name: true,
            username: true,
            role: true,
            createdAt: true,
            location: true,
            disabledAt: true,
          },
        },
      },
    });
    if (!recoveryCase) throw new NotFoundException('No such recovery case');

    return {
      ...this.staffSummary(recoveryCase),
      evidence: recoveryCase.evidence,
      risk_notes: recoveryCase.riskNotes,
      // Enough to recognise the account, and nothing that would let a reviewer
      // read her order history out of a support tool.
      account: recoveryCase.user
        ? {
            id: recoveryCase.user.id,
            name: recoveryCase.user.name,
            username: recoveryCase.user.username,
            role: recoveryCase.user.role.toLowerCase(),
            registered_at: recoveryCase.user.createdAt.toISOString(),
            location: recoveryCase.user.location,
            disabled: recoveryCase.user.disabledAt !== null,
          }
        : null,
      events: recoveryCase.events.map((event) => ({
        action: event.action,
        actor_id: event.actorId,
        note: event.note,
        at: event.createdAt.toISOString(),
      })),
    };
  }

  /**
   * One half of the dual control.
   *
   * The second approver must be a different account, and that is checked
   * against the stored first approver rather than against "the current user is
   * not the one in this request" — the distinction matters, because the whole
   * point is that a single compromised staff login cannot walk a case all the
   * way through on its own.
   */
  async approve(caseId: string, approverId: string, note: string | undefined, context: RequestContext) {
    const recoveryCase = await this.prisma.accountRecoveryCase.findUnique({
      where: { id: caseId },
    });
    if (!recoveryCase) throw new NotFoundException('No such recovery case');
    if (!recoveryCase.userId) {
      throw new BadRequestException({
        code: 'RECOVERY_CASE_UNRESOLVED',
        message: 'This case is not attached to an account and cannot be approved',
      });
    }
    if (
      recoveryCase.status !== AccountRecoveryStatus.SUBMITTED &&
      recoveryCase.status !== AccountRecoveryStatus.UNDER_REVIEW &&
      recoveryCase.status !== AccountRecoveryStatus.AWAITING_SECOND_APPROVAL
    ) {
      throw new BadRequestException({
        code: 'RECOVERY_CASE_CLOSED',
        message: 'That recovery request is already closed',
      });
    }
    if (recoveryCase.expiresAt < new Date()) {
      await this.transition(
        caseId,
        AccountRecoveryStatus.EXPIRED,
        {},
        { actorId: approverId, action: 'expired' },
      );
      throw new BadRequestException({
        code: 'RECOVERY_CASE_EXPIRED',
        message: 'That recovery request has expired',
      });
    }

    const now = new Date();

    // ── First approval ──────────────────────────────────────────────────
    if (!recoveryCase.firstApproverId) {
      await this.transition(
        caseId,
        AccountRecoveryStatus.AWAITING_SECOND_APPROVAL,
        { firstApproverId: approverId, firstApprovedAt: now },
        { actorId: approverId, action: 'approved', note },
      );
      await this.audit.record({
        actorId: approverId,
        action: 'recovery_case_first_approval',
        category: 'auth',
        outcome: 'success',
        severity: AuditSeverity.CRITICAL,
        context,
        metadata: { case_id: caseId },
      });
      return {
        case_id: caseId,
        status: AccountRecoveryStatus.AWAITING_SECOND_APPROVAL.toLowerCase(),
        approvals: 1,
      };
    }

    if (recoveryCase.firstApproverId === approverId) {
      throw new ForbiddenException({
        code: 'DUAL_CONTROL_REQUIRED',
        message: 'A second, different reviewer must approve this case',
      });
    }
    if (recoveryCase.secondApproverId) {
      throw new ConflictException({
        code: 'RECOVERY_CASE_ALREADY_APPROVED',
        message: 'That recovery request has already been approved',
      });
    }

    // ── Second approval: the clock starts, and she is told ───────────────
    const coolOffUntil = new Date(now.getTime() + COOL_OFF_MS);
    await this.transition(
      caseId,
      AccountRecoveryStatus.COOLING_OFF,
      {
        secondApproverId: approverId,
        secondApprovedAt: now,
        coolOffUntil,
      },
      { actorId: approverId, action: 'cool_off_started', note },
    );

    await this.prisma.securityEvent.create({
      data: {
        actorId: recoveryCase.userId,
        type: SecurityEventType.RECOVERY_CASE_APPROVED,
        riskLevel: RiskLevel.CRITICAL,
        resource: `recovery_case:${caseId}`,
        metadata: {
          first_approver: recoveryCase.firstApproverId,
          second_approver: approverId,
          cool_off_until: coolOffUntil.toISOString(),
        },
      },
    });
    await this.notifyOwner(
      recoveryCase.userId,
      'تحذير: طلب استعادة حسابكِ تمت الموافقة عليه',
      'سيُنقل حسابكِ إلى رقم آخر بعد 72 ساعة. إن لم تكوني أنت من طلب ذلك، ألغي الطلب فورًا من هذا الإشعار.',
      { action: 'recovery_case_cooling_off', case_id: caseId },
    );
    await this.audit.record({
      actorId: approverId,
      action: 'recovery_case_second_approval',
      category: 'auth',
      outcome: 'success',
      severity: AuditSeverity.CRITICAL,
      context,
      metadata: { case_id: caseId, cool_off_until: coolOffUntil.toISOString() },
    });

    return {
      case_id: caseId,
      status: AccountRecoveryStatus.COOLING_OFF.toLowerCase(),
      approvals: 2,
      completes_at: coolOffUntil.toISOString(),
    };
  }

  async reject(
    caseId: string,
    reviewerId: string,
    reason: string,
    context: RequestContext,
  ) {
    const recoveryCase = await this.prisma.accountRecoveryCase.findUnique({
      where: { id: caseId },
    });
    if (!recoveryCase) throw new NotFoundException('No such recovery case');
    if (!this.isLive(recoveryCase.status)) {
      throw new BadRequestException({
        code: 'RECOVERY_CASE_CLOSED',
        message: 'That recovery request is already closed',
      });
    }

    await this.transition(
      caseId,
      AccountRecoveryStatus.REJECTED,
      { rejectedAt: new Date(), rejectedReason: reason },
      { actorId: reviewerId, action: 'rejected', note: reason },
    );
    if (recoveryCase.userId) {
      await this.prisma.securityEvent.create({
        data: {
          actorId: recoveryCase.userId,
          type: SecurityEventType.RECOVERY_CASE_REJECTED,
          riskLevel: RiskLevel.MEDIUM,
          resource: `recovery_case:${caseId}`,
          metadata: { reason },
        },
      });
    }
    await this.audit.record({
      actorId: reviewerId,
      action: 'recovery_case_rejected',
      category: 'auth',
      outcome: 'success',
      severity: AuditSeverity.WARNING,
      context,
      metadata: { case_id: caseId, reason },
    });

    return { case_id: caseId, status: 'rejected' };
  }

  // ──────────────────────────── Completion ────────────────────────────

  /**
   * Hands over every case whose cool-off has run out.
   *
   * Driven by the retention cron rather than by a request, because the thing
   * that makes a case complete is *time passing*, and nothing else. Tying it to
   * a staff click would put the final step back in the hands of one person.
   */
  async completeMaturedCases(now = new Date()): Promise<number> {
    const matured = await this.prisma.accountRecoveryCase.findMany({
      where: {
        status: AccountRecoveryStatus.COOLING_OFF,
        coolOffUntil: { lte: now },
      },
      take: 50,
    });

    let completed = 0;
    for (const recoveryCase of matured) {
      try {
        await this.complete(recoveryCase.id, now);
        completed += 1;
      } catch (error) {
        this.logger.error(
          `Recovery case ${recoveryCase.id} failed to complete: ${
            error instanceof Error ? error.message : 'unknown error'
          }`,
        );
      }
    }
    return completed;
  }

  private async complete(caseId: string, now: Date): Promise<void> {
    const recoveryCase = await this.prisma.accountRecoveryCase.findUnique({
      where: { id: caseId },
    });
    if (
      !recoveryCase ||
      recoveryCase.status !== AccountRecoveryStatus.COOLING_OFF ||
      !recoveryCase.userId ||
      !recoveryCase.newPhone
    ) {
      return;
    }

    // The number may well have been claimed by somebody else during the three
    // days. Refuse rather than collide: she can open a new case.
    const collision = await this.prisma.user.findUnique({
      where: { phone: recoveryCase.newPhone },
    });
    if (collision && collision.id !== recoveryCase.userId) {
      await this.transition(
        caseId,
        AccountRecoveryStatus.REJECTED,
        { rejectedAt: now, rejectedReason: 'contact_phone_taken' },
        { action: 'rejected', note: 'contact_phone_taken' },
      );
      return;
    }

    const payoutFrozenUntil = new Date(now.getTime() + PAYOUT_FREEZE_MS);
    const userId = recoveryCase.userId;

    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: {
          phone: recoveryCase.newPhone,
          phoneVerifiedAt: now,
          // Everything the previous holder could authenticate with is gone.
          // The premise of the case is that she cannot use any of it, so
          // leaving it in place only preserves the attacker's access in the
          // scenario where the case was fraudulent.
          passwordHash: null,
          passwordSetAt: null,
          failedLoginCount: 0,
          lockedUntil: null,
          payoutFrozenUntil,
          payoutFreezeReason: 'account_recovery',
        },
      });

      await tx.session.updateMany({
        where: { userId, status: SessionStatus.ACTIVE },
        data: {
          status: SessionStatus.REVOKED,
          revokedAt: now,
          revokedReason: 'account_recovered',
        },
      });
      await tx.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: now },
      });
      await tx.deviceKey.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: now, revokedReason: 'account_recovered' },
      });
      await tx.recoveryCode.deleteMany({ where: { userId } });
      await tx.totpCredential.deleteMany({ where: { userId } });

      await tx.accountRecoveryCase.update({
        where: { id: caseId },
        data: {
          status: AccountRecoveryStatus.COMPLETED,
          completedAt: now,
        },
      });
      await tx.accountRecoveryEvent.create({
        data: {
          caseId,
          action: 'completed',
          metadata: {
            payout_frozen_until: payoutFrozenUntil.toISOString(),
          } as Prisma.InputJsonValue,
        },
      });
    });

    await this.prisma.securityEvent.createMany({
      data: [
        {
          actorId: userId,
          type: SecurityEventType.RECOVERY_CASE_COMPLETED,
          riskLevel: RiskLevel.CRITICAL,
          resource: `recovery_case:${caseId}`,
          metadata: { new_phone: maskDestination(recoveryCase.newPhone) },
        },
        {
          actorId: userId,
          type: SecurityEventType.PAYOUT_FROZEN,
          riskLevel: RiskLevel.HIGH,
          metadata: {
            reason: 'account_recovery',
            until: payoutFrozenUntil.toISOString(),
          },
        },
      ],
    });
    await this.audit.record({
      actorId: userId,
      action: 'recovery_case_completed',
      category: 'auth',
      outcome: 'success',
      severity: AuditSeverity.CRITICAL,
      metadata: { case_id: caseId },
    });
  }

  // ───────────────────────────── Internals ─────────────────────────────

  /**
   * Scores what she knew against what only the platform holds.
   *
   * Nothing here is ever echoed back — not which answers matched, not the
   * expected values. The claimant is told "submitted" and nothing more, because
   * an oracle that says "the month was right, the order total was wrong" turns
   * this into a guessing game somebody can grind.
   */
  private scoreEvidence(
    dto: SubmitRecoveryCaseDto,
    user: User & {
      orders: { grandTotal: Prisma.Decimal; createdAt: Date; number: string }[];
      deviceKeys: { label: string | null; model: string | null }[];
      devices: { name: string }[];
    },
  ): EvidenceCheck[] {
    const lastOrder = user.orders[0];
    const deviceLabels = [
      ...user.deviceKeys.map((key) => key.label ?? key.model ?? ''),
      ...user.devices.map((device) => device.name),
    ]
      .filter((label) => label.length > 0)
      .map((label) => this.normalise(label));

    return [
      this.check('registration_month', 25, dto.registration_month, (answer) =>
        answer === this.monthOf(user.createdAt),
      ),
      this.check('display_name', 10, dto.display_name, (answer) =>
        [user.name, user.username].some(
          (candidate) => this.normalise(candidate) === this.normalise(answer),
        ),
      ),
      this.check('city', 10, dto.city, (answer) =>
        this.normalise(user.location ?? '').includes(this.normalise(answer)),
      ),
      this.check('last_order_month', 15, dto.last_order_month, (answer) =>
        lastOrder ? answer === this.monthOf(lastOrder.createdAt) : false,
      ),
      this.check('last_order_total', 25, dto.last_order_total, (answer) => {
        if (!lastOrder) return false;
        const actual = Number(lastOrder.grandTotal);
        const claimed = Number(answer);
        if (!Number.isFinite(claimed) || actual === 0) return false;
        // Within 2%: she remembers roughly what she paid, not the fourth
        // decimal place of a rounded Syrian pound total.
        return Math.abs(actual - claimed) / actual <= 0.02;
      }),
      this.check('device_label', 15, dto.device_label, (answer) =>
        deviceLabels.some((label) => label.includes(this.normalise(answer))),
      ),
    ];
  }

  private check(
    key: string,
    weight: number,
    answer: string | number | undefined,
    matcher: (answer: string) => boolean,
  ): EvidenceCheck {
    const answered = answer !== undefined && String(answer).trim().length > 0;
    return {
      key,
      weight,
      answered,
      matched: answered ? matcher(String(answer).trim()) : false,
    };
  }

  private riskNotesFor(
    user: User | null,
    score: number,
    privileged: boolean,
  ): string | null {
    if (privileged) {
      return 'Privileged account. Support-mediated recovery is refused by policy; handle out of band with the platform owner.';
    }
    if (!user) return 'No account matches the claimed number.';
    if (score < REVIEWABLE_SCORE) {
      return `Weak evidence (${score}/100). Do not approve without additional context from a channel the claimant did not choose.`;
    }
    return null;
  }

  private staffSummary(item: {
    id: string;
    status: AccountRecoveryStatus;
    claimedPhone: string;
    contactPhone: string;
    score: number;
    userId: string | null;
    firstApproverId: string | null;
    secondApproverId: string | null;
    coolOffUntil: Date | null;
    createdAt: Date;
    expiresAt: Date;
  }) {
    return {
      case_id: item.id,
      status: item.status.toLowerCase(),
      // Masked even for staff. A support tool is not a phone book.
      claimed_phone: maskDestination(item.claimedPhone),
      contact_phone: maskDestination(item.contactPhone),
      score: item.score,
      user_id: item.userId,
      approvals: [item.firstApproverId, item.secondApproverId].filter(Boolean)
        .length,
      first_approver_id: item.firstApproverId,
      second_approver_id: item.secondApproverId,
      completes_at: item.coolOffUntil?.toISOString() ?? null,
      submitted_at: item.createdAt.toISOString(),
      expires_at: item.expiresAt.toISOString(),
    };
  }

  private async transition(
    caseId: string,
    status: AccountRecoveryStatus,
    data: Prisma.AccountRecoveryCaseUpdateInput,
    event: { actorId?: string; action: string; note?: string },
  ) {
    await this.prisma.$transaction([
      this.prisma.accountRecoveryCase.update({
        where: { id: caseId },
        data: { ...data, status },
      }),
      this.prisma.accountRecoveryEvent.create({
        data: {
          caseId,
          actorId: event.actorId,
          action: event.action,
          note: event.note,
        },
      }),
    ]);
  }

  private async notifyOwner(
    userId: string,
    title: string,
    body: string,
    data: Record<string, unknown>,
  ) {
    await this.prisma.notification.create({
      data: {
        userId,
        title,
        body,
        type: NotificationType.system,
        data: this.json(data),
      },
    });
  }

  private isLive(status: AccountRecoveryStatus): boolean {
    return (
      status === AccountRecoveryStatus.SUBMITTED ||
      status === AccountRecoveryStatus.UNDER_REVIEW ||
      status === AccountRecoveryStatus.AWAITING_SECOND_APPROVAL ||
      status === AccountRecoveryStatus.COOLING_OFF
    );
  }

  private monthOf(date: Date): string {
    return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
  }

  private normalise(value: string): string {
    return value.trim().toLowerCase().replace(/\s+/g, ' ');
  }

  private digest(secret: string): string {
    return createHmac('sha256', this.pepper).update(secret).digest('hex');
  }

  private secretMatches(secret: string, storedHash: string): boolean {
    const expected = Buffer.from(storedHash, 'utf8');
    const actual = Buffer.from(this.digest(secret), 'utf8');
    if (expected.length !== actual.length) return false;
    return timingSafeEqual(expected, actual);
  }

  private json(value: unknown): Prisma.InputJsonValue {
    return value as Prisma.InputJsonValue;
  }
}
