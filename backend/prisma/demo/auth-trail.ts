import {
  AuditSeverity,
  CommerceContentAnalyticsEventType,
  CommerceContentModerationStatus,
  MessageKind,
  OtpChannel,
  OtpPurpose,
  OtpStatus,
  SellerVerificationStatus,
} from '@prisma/client';
import { DemoContext } from './context';

/**
 * Login attempts, OTP requests, linked social accounts and the seller
 * verification timeline — everything the account-security and admin-audit
 * screens read but nothing else writes during a fresh install.
 */
export async function seedAuthTrail(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;

  for (const customer of ctx.customers.slice(0, 8)) {
    for (let attempt = 0; attempt < rng.int(1, 4); attempt += 1) {
      await prisma.loginAttempt.create({
        data: {
          userId: customer.id,
          phone: customer.phone,
          success: true,
          ipAddress: `31.9.${rng.int(1, 254)}.${rng.int(1, 254)}`,
          userAgent: 'Reem/1.4.0 (android)',
          createdAt: rng.pastDate(30),
        },
      });
    }
  }

  // A brute-force burst against one number — what the lockout logic reacts to.
  const target = ctx.customers[1];
  for (let attempt = 0; attempt < 4; attempt += 1) {
    await prisma.loginAttempt.create({
      data: {
        userId: target.id,
        phone: target.phone,
        success: false,
        reason: 'INVALID_PASSWORD',
        ipAddress: '185.203.11.42',
        userAgent: 'python-requests/2.31',
        severity: AuditSeverity.WARNING,
        createdAt: rng.pastDate(4),
      },
    });
  }

  // OTP history: verified sign-ups plus one code still in flight.
  for (const customer of ctx.customers.slice(0, 5)) {
    const createdAt = rng.pastDate(60, 2);
    await prisma.otpRequest.create({
      data: {
        userId: customer.id,
        destination: customer.phone,
        // Q47 P1 — WhatsApp is the primary OTP channel in Syria.
        channel: OtpChannel.WHATSAPP,
        purpose: OtpPurpose.PHONE_VERIFICATION,
        codeHash: `hashed-${customer.id.slice(0, 8)}`,
        status: OtpStatus.VERIFIED,
        attempts: 1,
        expiresAt: new Date(createdAt.getTime() + 6e5),
        verifiedAt: new Date(createdAt.getTime() + 9e4),
        createdAt,
      },
    });
  }

  const pendingFor = ctx.customers[5];
  await prisma.otpRequest.create({
    data: {
      userId: pendingFor.id,
      destination: pendingFor.phone,
      channel: OtpChannel.SMS,
      purpose: OtpPurpose.PASSWORD_RESET,
      codeHash: 'hashed-pending',
      status: OtpStatus.PENDING,
      expiresAt: new Date(Date.now() + 5 * 60_000),
    },
  });

  // Verification timeline — the seller onboarding screen renders this history.
  const verifications = await prisma.sellerVerification.findMany({
    select: { id: true, status: true, submittedAt: true },
  });

  for (const verification of verifications) {
    const steps: { status: SellerVerificationStatus; reason: string }[] = [
      {
        status: SellerVerificationStatus.PENDING,
        reason: 'تم استلام طلب التوثيق',
      },
      {
        status: SellerVerificationStatus.UNDER_REVIEW,
        reason: 'جاري التحقق من المستندات',
      },
    ];
    if (verification.status === SellerVerificationStatus.APPROVED) {
      steps.push({
        status: SellerVerificationStatus.APPROVED,
        reason: 'اكتملت المستندات وتمت الموافقة',
      });
    }

    for (const [index, step] of steps.entries()) {
      await prisma.sellerVerificationStatusHistory.create({
        data: {
          verificationId: verification.id,
          status: step.status,
          reason: step.reason,
          adminId: index === 0 ? null : ctx.adminId,
          createdAt: new Date(
            verification.submittedAt.getTime() + index * 36e5,
          ),
        },
      });
    }
  }
}

/**
 * Per-viewer analytics and moderation decisions on rich content — the numbers
 * behind the seller content dashboard, which otherwise only has roll-up
 * columns with nothing to drill into.
 */
export async function seedContentAnalytics(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;

  const contents = await prisma.commerceContent.findMany({
    where: { status: 'PUBLISHED' },
    select: { id: true, sellerId: true, publishedAt: true },
  });

  const audience = ctx.customers.map((customer) => customer.id);

  for (const content of contents) {
    for (const userId of rng.sample(audience, rng.int(3, 9))) {
      const firstViewedAt = rng.pastDate(30, 0);
      await prisma.commerceContentViewer.create({
        data: {
          contentId: content.id,
          userId,
          viewsCount: rng.int(1, 4),
          firstViewedAt,
          lastViewedAt: new Date(firstViewedAt.getTime() + rng.int(1, 72) * 36e5),
        },
      });

      await prisma.commerceContentEvent.create({
        data: {
          contentId: content.id,
          actorId: userId,
          type: rng.weighted<CommerceContentAnalyticsEventType>([
            [CommerceContentAnalyticsEventType.VIEW, 6],
            [CommerceContentAnalyticsEventType.PRODUCT_CLICK, 3],
            [CommerceContentAnalyticsEventType.SAVE, 2],
            [CommerceContentAnalyticsEventType.SHARE, 1],
            [CommerceContentAnalyticsEventType.ADD_TO_CART, 1],
          ]),
          value: rng.float(0, 1, 2),
          createdAt: firstViewedAt,
        },
      });
    }

    await prisma.commerceContentModerationAction.create({
      data: {
        contentId: content.id,
        moderatorId: ctx.adminId,
        fromStatus: CommerceContentModerationStatus.PENDING,
        toStatus: CommerceContentModerationStatus.APPROVED,
        reason: 'مطابق لسياسة المحتوى',
        createdAt: content.publishedAt ?? rng.pastDate(30),
      },
    });
  }
}

/** One image attachment, so the chat bubble renderer has a non-text case. */
export async function seedMessageAttachments(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;

  const messages = await prisma.message.findMany({
    take: 3,
    orderBy: { createdAt: 'desc' },
    select: { id: true },
  });

  for (const message of messages) {
    await prisma.messageAttachment.create({
      data: {
        messageId: message.id,
        kind: MessageKind.IMAGE,
        url: `https://loremflickr.com/720/900/fashion,detail/all?lock=${rng.int(1, 9999)}`,
        mimeType: 'image/jpeg',
        fileName: 'product.jpg',
        sizeBytes: rng.int(80_000, 400_000),
        width: 720,
        height: 900,
      },
    });
  }
}
