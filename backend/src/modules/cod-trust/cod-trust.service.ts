import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import {
  AuditSeverity,
  CodAssurance,
  CodAssuranceState,
  CodRiskAssessment,
  CodRiskTier,
  OtpPurpose,
  PaymentMethodType,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../auth/audit.service';
import { OtpService } from '../auth/otp.service';
import {
  BasketInput,
  CodFactsService,
  DestinationInput,
} from './cod-facts.service';
import { CONFIRMATION_TTL_MINUTES } from './cod-trust.constants';
import { CodFacts, CodRiskScore } from './kernel/cod-facts';
import { CodDecision, decideCodAssurance } from './kernel/cod-policy';
import { scoreCodRisk } from './kernel/cod-risk';

/** The rails where a courier ends up holding the customer's cash. */
const CASH_RAILS: PaymentMethodType[] = [
  PaymentMethodType.COD,
  PaymentMethodType.COURIER_COLLECT,
];

/**
 * What the parcel did in the end.
 *
 * A closed vocabulary rather than free text, because the whole point of the
 * column is that somebody can one day group by it and find out whether the
 * weights are any good.
 */
export type CodOutcome = 'delivered' | 'refused' | 'failed' | 'cancelled';

export interface CodAssessment {
  facts: CodFacts;
  score: CodRiskScore;
  decision: CodDecision;
  exposureUsd: number;
}

/**
 * Whether cash goes out on the road for this basket, and what is asked for
 * first.
 *
 * The service is a thin shell on purpose: it gathers facts, hands them to two
 * pure functions, and writes down what they said. Every judgement lives in
 * `kernel/`, where it can be tested without a database and read without
 * following a call graph.
 *
 * What this service deliberately does **not** do:
 *
 * - It never refuses a sale. The worst outcome it can produce is that a basket
 *   has to be paid for before it ships.
 * - It never tells the customer her score, or that a score exists. She is told
 *   what is needed and why in one sentence; the number is for the people who
 *   have to answer for the decision.
 * - It never runs for a prepaid order. There is no cash on the road to lose,
 *   so scoring one would be surveillance with no purpose.
 */
@Injectable()
export class CodTrustService {
  private readonly logger = new Logger(CodTrustService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly facts: CodFactsService,
    private readonly otp: OtpService,
    private readonly audit: AuditService,
  ) {}

  /** True when this payment method puts cash in a courier's hands. */
  static isCashRail(method: PaymentMethodType): boolean {
    return CASH_RAILS.includes(method);
  }

  /**
   * Scores a basket that has not been placed yet.
   *
   * Called from checkout before the order row exists, because a decision that
   * can only be taken after the sellers have been told to prepare a parcel is
   * not a decision, it is a report.
   */
  async assess(input: {
    userId: string | null;
    destination: DestinationInput;
    basket: BasketInput;
  }): Promise<CodAssessment> {
    const facts = await this.facts.gather(input);
    const score = scoreCodRisk(facts);
    const decision = decideCodAssurance(score, facts);
    return {
      facts,
      score,
      decision,
      exposureUsd: input.basket.orderValueUsd,
    };
  }

  /**
   * Writes the assessment against the order it was made for.
   *
   * Takes the transaction so the assessment and the order it gated are one
   * write: an order that exists without the reasoning that let it exist is
   * exactly the gap somebody would have to fill in from memory six months
   * later.
   */
  async record(
    tx: Prisma.TransactionClient,
    input: {
      orderId: string;
      userId: string | null;
      assessment: CodAssessment;
      state: CodAssuranceState;
    },
  ): Promise<CodRiskAssessment> {
    const { assessment } = input;
    return tx.codRiskAssessment.create({
      data: {
        orderId: input.orderId,
        userId: input.userId,
        score: new Prisma.Decimal(assessment.score.score),
        confidence: new Prisma.Decimal(assessment.score.confidence),
        tier: assessment.decision.tier,
        assurance: assessment.decision.assurance,
        state: input.state,
        factors: assessment.score.factors as unknown as Prisma.InputJsonValue,
        ruleCodes: assessment.decision.ruleCodes,
        exposureUsd: new Prisma.Decimal(assessment.exposureUsd.toFixed(4)),
        expiresAt:
          input.state === CodAssuranceState.PENDING
            ? new Date(Date.now() + CONFIRMATION_TTL_MINUTES * 60_000)
            : null,
      },
    });
  }

  /**
   * Sends the confirmation code for an order that is being held.
   *
   * Sent to the number on the *order*, not the number on the account. The two
   * differ whenever she is shipping to her mother, and the question this code
   * answers is whether a live human at the delivery number is expecting a
   * courier with a bill.
   */
  async requestConfirmation(input: {
    orderId: string;
    orderNumber: string;
    recipientPhone: string;
    userId: string | null;
  }) {
    const challenge = await this.otp.request({
      phone: input.recipientPhone,
      purpose: OtpPurpose.ORDER_CONFIRMATION,
      userId: input.userId ?? undefined,
    });

    await this.prisma.codRiskAssessment.update({
      where: { orderId: input.orderId },
      data: { otpRequestId: challenge.otp_request_id },
    });

    return challenge;
  }

  /**
   * Consumes the code and releases the order.
   *
   * Returns `true` when the order should now be confirmed by the caller. The
   * confirmation itself belongs to checkout — this service knows whether the
   * customer proved anything, not what a confirmed order does next.
   */
  async satisfyConfirmation(input: {
    orderId: string;
    recipientPhone: string;
    /** Absent on the reverse rail, where the recipient sent the message. */
    code?: string;
    actorId: string | null;
  }): Promise<boolean> {
    const assessment = await this.prisma.codRiskAssessment.findUnique({
      where: { orderId: input.orderId },
    });

    if (!assessment || assessment.assurance !== CodAssurance.ORDER_CONFIRMATION) {
      throw new BadRequestException('This order is not awaiting a code');
    }
    if (assessment.state === CodAssuranceState.SATISFIED) {
      return false;
    }
    if (assessment.expiresAt && assessment.expiresAt < new Date()) {
      await this.prisma.codRiskAssessment.update({
        where: { id: assessment.id },
        data: { state: CodAssuranceState.ABANDONED },
      });
      throw new BadRequestException({
        code: 'COD_CONFIRMATION_EXPIRED',
        message: 'انتهت مهلة تأكيد الطلب. أعيدي إرسال الرمز أو غيّري طريقة الدفع.',
      });
    }

    // `consumeAny` rather than `verifyAny`: proving control of the delivery
    // number must not mark the *account's* number verified, and on an order
    // shipping to somebody else's phone it would be marking the wrong number.
    // `Any` because the challenge may have been opened on either rail.
    await this.otp.consumeAny(
      input.recipientPhone,
      OtpPurpose.ORDER_CONFIRMATION,
      input.code,
    );

    await this.prisma.codRiskAssessment.update({
      where: { id: assessment.id },
      data: {
        state: CodAssuranceState.SATISFIED,
        satisfiedAt: new Date(),
      },
    });

    await this.audit.record({
      actorId: input.actorId,
      action: 'cod_confirmation_satisfied',
      category: 'commerce.cod_trust',
      outcome: 'success',
      metadata: {
        order_id: input.orderId,
        tier: assessment.tier,
        score: assessment.score.toString(),
      },
    });

    return true;
  }

  /**
   * Records what the parcel actually did.
   *
   * This is the only column that can ever prove the weights wrong. A run of
   * parcels scored below 30 and refused at the door says the model is blind to
   * something; a run of 80s that all delivered says the platform is charging
   * its best customers for a risk that is not there. Without the pairing,
   * every tuning argument is a matter of taste.
   */
  async observe(orderId: string, outcome: CodOutcome): Promise<void> {
    try {
      await this.prisma.codRiskAssessment.updateMany({
        where: {
          orderId,
          // A refusal overwrites whatever was recorded first. An order split
          // across three sellers can have two parcels delivered and one sent
          // back, and the one sent back is the event the engine exists to
          // predict — letting the first parcel's success bury it would train
          // the weights on the wrong half of the order.
          ...(outcome === 'refused' ? {} : { observedOutcome: null }),
        },
        data: { observedOutcome: outcome, observedAt: new Date() },
      });
    } catch (error) {
      // An outcome we failed to write is a worse model later, never a failed
      // delivery now.
      this.logger.warn(
        `Could not record COD outcome for order ${orderId}: ${
          (error as Error).message
        }`,
      );
    }
  }

  /**
   * The same, addressed by the parcel the courier was actually holding.
   *
   * Couriers work on sub-orders; the assessment was made about the basket. The
   * lookup lives here rather than in every caller so that delivery code never
   * has to know the assessment hangs off the parent.
   */
  async observeBySellerOrder(
    sellerOrderId: string,
    outcome: CodOutcome,
  ): Promise<void> {
    const sellerOrder = await this.prisma.sellerOrder.findUnique({
      where: { id: sellerOrderId },
      select: { orderId: true },
    });
    if (sellerOrder) await this.observe(sellerOrder.orderId, outcome);
  }

  /** Audits a decision that changed what the customer was asked to do. */
  async auditDecision(input: {
    orderId: string;
    orderNumber: string;
    userId: string | null;
    assessment: CodAssessment;
  }): Promise<void> {
    const { decision, score } = input.assessment;
    if (decision.assurance === CodAssurance.NONE) return;

    await this.audit.record({
      actorId: input.userId,
      action: 'cod_assurance_required',
      category: 'commerce.cod_trust',
      outcome: decision.assurance.toLowerCase(),
      severity:
        decision.assurance === CodAssurance.PREPAYMENT
          ? AuditSeverity.WARNING
          : AuditSeverity.INFO,
      metadata: {
        order_id: input.orderId,
        order_number: input.orderNumber,
        tier: decision.tier,
        score: score.score,
        confidence: score.confidence,
        rules: decision.ruleCodes,
      },
    });
  }
}

/**
 * What the customer is told, in one sentence.
 *
 * She is never shown a score, a tier or a factor. Telling a woman that an
 * algorithm rated her 74 invites her to argue with a number nobody in support
 * can change, and telling her which signal fired teaches the small number of
 * people gaming cash on delivery exactly what to avoid. What she gets is the
 * thing she can act on.
 */
export function customerMessageFor(
  assurance: CodAssurance,
  ruleCodes: string[],
): string | null {
  switch (assurance) {
    case CodAssurance.NONE:
      return null;
    case CodAssurance.ORDER_CONFIRMATION:
      return ruleCodes.includes('first_order_above_threshold')
        ? 'لأنه طلبك الأول بالدفع عند الاستلام، أرسلنا رمزاً إلى رقم التوصيل — أدخليه لتأكيد الطلب.'
        : 'أرسلنا رمزاً إلى رقم التوصيل للتأكد من الطلب — أدخليه ليصل إلى البائعة.';
    case CodAssurance.PREPAYMENT:
      return 'الدفع عند الاستلام غير متاح لهذا الطلب. اختاري سيريتل كاش أو شام كاش أو الدفع من المحفظة، وسيُشحن فوراً.';
  }
}

/** The seller-facing label. Sellers see the tier; only admins see the score. */
export function sellerLabelFor(tier: CodRiskTier): string {
  switch (tier) {
    case CodRiskTier.TRUSTED:
      return 'زبونة موثوقة';
    case CodRiskTier.LOW:
      return 'مخاطرة منخفضة';
    case CodRiskTier.MEDIUM:
      return 'تحتاج انتباهاً';
    case CodRiskTier.HIGH:
      return 'احتمال رفض مرتفع';
  }
}
