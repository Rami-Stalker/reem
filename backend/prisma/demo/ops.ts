import {
  AiGenerationStatus,
  AiGenerationType,
  AiInteractionType,
  AnalyticsEventType,
  AnalyticsExportFormat,
  AuditSeverity,
  ModerationStatus,
  NotificationCampaignStatus,
  NotificationChannel,
  NotificationDeliveryStatus,
  Prisma,
  ReportStatus,
  RiskLevel,
  SecurityEventType,
  SupportPriority,
  SupportTicketStatus,
} from '@prisma/client';
import { SEARCH_QUERIES, SUPPORT_TICKETS } from './data';
import { DemoContext } from './context';
import { SeededOrder } from './commerce';

/**
 * Behavioural analytics.
 *
 * Events are generated per *session* rather than independently, so the funnel
 * actually narrows: every cart-add belongs to a session that viewed a product
 * first, and every payment belongs to one that placed an order. Independent
 * random events would give the conversion and funnel endpoints impossible
 * numbers (more checkouts than product views).
 */
export async function seedAnalytics(
  ctx: DemoContext,
  orders: SeededOrder[],
): Promise<void> {
  const { prisma, rng } = ctx;

  const shoppers = [...ctx.customers.map((customer) => customer.id), null];
  const rows: Prisma.AnalyticsEventCreateManyInput[] = [];
  const sources = ['android', 'ios', 'web'];

  for (let session = 0; session < 700; session += 1) {
    const userId = rng.pick(shoppers);
    const source = rng.pick(sources);
    const sessionId = `sess-${session}`;
    let cursor = rng.pastDate(90, 0);

    const step = (type: AnalyticsEventType, extra: Partial<Prisma.AnalyticsEventCreateManyInput> = {}) => {
      cursor = new Date(cursor.getTime() + rng.int(20, 600) * 1000);
      rows.push({
        type,
        userId,
        sessionId,
        source,
        occurredAt: cursor,
        createdAt: cursor,
        ...extra,
      });
    };

    step(AnalyticsEventType.APP_OPEN);

    for (let search = 0; search < rng.int(0, 2); search += 1) {
      step(AnalyticsEventType.PRODUCT_SEARCH, {
        metadata: { query: rng.pick(SEARCH_QUERIES) },
      });
    }

    const viewed = rng.sample(ctx.products, rng.int(1, 5));
    for (const product of viewed) {
      step(AnalyticsEventType.PRODUCT_VIEW, {
        productId: product.id,
        sellerId: product.offers[0]?.sellerId ?? null,
      });
    }

    if (rng.bool(0.3)) {
      step(AnalyticsEventType.SELLER_VIEW, {
        sellerId: rng.pick(ctx.sellers).id,
      });
    }

    if (!rng.bool(0.34)) continue;
    const carted = rng.pick(viewed);
    step(AnalyticsEventType.CART_ADD, {
      productId: carted.id,
      sellerId: carted.offers[0]?.sellerId ?? null,
    });

    if (!rng.bool(0.52)) continue;
    step(AnalyticsEventType.CHECKOUT_START, { productId: carted.id });

    if (!rng.bool(0.61)) continue;
    step(AnalyticsEventType.ORDER_PLACED, { productId: carted.id });

    if (!rng.bool(0.92)) continue;
    step(AnalyticsEventType.PAYMENT_SUCCESS, { productId: carted.id });
  }

  // Every real order gets the whole tail of the funnel, not just its ending.
  //
  // This loop used to push a bare `ORDER_PLACED` linked to the order row —
  // which revenue attribution needs — and nothing before it. Six hundred and
  // fifty-one orders therefore arrived with no cart-add and no checkout of
  // their own, and the console's conversion funnel showed more orders placed
  // than checkouts started: a funnel that widens at the bottom, which is the
  // exact impossibility the note at the top of this file says the per-session
  // generation exists to avoid.
  //
  // The three steps before it are stamped at fixed offsets rather than random
  // ones so the seed stays reproducible.
  for (const order of orders) {
    const at = (minutesBefore: number) =>
      new Date(order.placedAt.getTime() - minutesBefore * 60_000);
    const session = `order-${order.number}`;
    const base = {
      userId: order.customerId,
      sessionId: session,
      source: 'android',
    };

    rows.push({
      ...base,
      type: AnalyticsEventType.CART_ADD,
      occurredAt: at(12),
      createdAt: at(12),
    });
    rows.push({
      ...base,
      type: AnalyticsEventType.CHECKOUT_START,
      occurredAt: at(4),
      createdAt: at(4),
    });
    rows.push({
      ...base,
      type: AnalyticsEventType.ORDER_PLACED,
      orderId: order.id,
      occurredAt: order.placedAt,
      createdAt: order.placedAt,
    });
  }

  for (let start = 0; start < rows.length; start += 500) {
    await prisma.analyticsEvent.createMany({
      data: rows.slice(start, start + 500),
    });
  }

  await prisma.analyticsExport.create({
    data: {
      requestedBy: ctx.adminId,
      format: AnalyticsExportFormat.EXCEL,
      reportType: 'sales',
      filters: { period: 'last_30_days' },
    },
  });
}

/** The assistant's history — recommendation logs and generated copy. */
export async function seedAiActivity(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;

  for (const customer of ctx.customers) {
    for (let index = 0; index < rng.int(1, 5); index += 1) {
      const product = rng.pick(ctx.products);
      await prisma.aiInteraction.create({
        data: {
          userId: customer.id,
          type: rng.weighted<AiInteractionType>([
            [AiInteractionType.RECOMMENDATION_VIEW, 4],
            [AiInteractionType.SEARCH_SUGGESTION, 3],
            [AiInteractionType.SIMILAR_PRODUCTS, 2],
            [AiInteractionType.HOME_FEED, 2],
          ]),
          query: rng.bool(0.4) ? rng.pick(SEARCH_QUERIES) : null,
          productId: product.id,
          sellerId: product.offers[0]?.sellerId ?? null,
          score: rng.float(0.4, 0.99, 3),
          createdAt: rng.pastDate(60),
        },
      });
    }
  }

  for (const seller of ctx.sellers) {
    const owned = ctx.products.filter((product) =>
      product.offers.some((offer) => offer.sellerId === seller.id),
    );
    if (owned.length === 0) continue;

    for (const product of rng.sample(owned, rng.int(1, 3))) {
      await prisma.aiGeneration.create({
        data: {
          userId: seller.id,
          productId: product.id,
          type: rng.bool(0.6)
            ? AiGenerationType.PRODUCT_DESCRIPTION
            : AiGenerationType.PRODUCT_TAGS,
          prompt: `اكتبي وصفاً تسويقياً لـ ${product.title}`,
          output: {
            description: `${product.title} — قطعة مختارة بعناية تناسب المناسبات والإطلالات اليومية.`,
            tags: ['جديد', 'الأكثر طلباً', product.leaf],
          },
          status: AiGenerationStatus.COMPLETED,
          createdAt: rng.pastDate(45),
        },
      });
    }
  }
}

/** Support desk, moderation queue, reports and platform settings. */
export async function seedBackOffice(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;

  for (const [index, ticket] of SUPPORT_TICKETS.entries()) {
    const author = ctx.customers[index % ctx.customers.length];
    const status = rng.weighted<SupportTicketStatus>([
      [SupportTicketStatus.OPEN, 3],
      [SupportTicketStatus.PENDING, 2],
      [SupportTicketStatus.RESOLVED, 2],
      [SupportTicketStatus.CLOSED, 1],
    ]);
    const createdAt = rng.pastDate(40, 1);

    const row = await prisma.supportTicket.create({
      data: {
        userId: author.id,
        subject: ticket.subject,
        status,
        priority: SupportPriority[ticket.priority],
        category: ticket.category,
        assignedTo:
          status === SupportTicketStatus.OPEN ? null : ctx.adminId,
        lastMessageAt: createdAt,
        createdAt,
      },
    });

    await prisma.supportMessage.create({
      data: {
        ticketId: row.id,
        authorId: author.id,
        body: 'مرحباً، أحتاج مساعدة بخصوص هذا الموضوع. شكراً لكم.',
        createdAt,
      },
    });

    if (status !== SupportTicketStatus.OPEN) {
      await prisma.supportMessage.create({
        data: {
          ticketId: row.id,
          authorId: ctx.adminId,
          body: 'أهلاً بكِ 🌸 تم استلام طلبك ونعمل عليه الآن.',
          createdAt: new Date(createdAt.getTime() + 3.6e6),
        },
      });
    }
  }

  // Moderation queue — product photos that break the content rules (Q84 P1)
  // are the most common case, so that is what the demo queue is made of.
  const flagged = rng.sample(ctx.products, 6);
  const reasons = [
    'الصورة تحتوي على عارضة أزياء — مخالف لسياسة المحتوى',
    'خلفية الصورة غير مناسبة',
    'وصف المنتج يحتوي على معلومات تواصل خارجية',
    'تصنيف المنتج غير صحيح',
  ];
  for (const [index, product] of flagged.entries()) {
    await prisma.moderationCase.create({
      data: {
        targetType: 'product',
        targetId: product.id,
        reporterId: rng.pick(ctx.customers).id,
        reason: reasons[index % reasons.length],
        status: rng.weighted<ModerationStatus>([
          [ModerationStatus.OPEN, 3],
          [ModerationStatus.APPROVED, 2],
          [ModerationStatus.REJECTED, 1],
          [ModerationStatus.ESCALATED, 1],
        ]),
        assignedTo: ctx.adminId,
        createdAt: rng.pastDate(30),
      },
    });
  }

  await prisma.adminReport.createMany({
    data: [
      {
        type: 'sales',
        title: 'تقرير المبيعات الشهري',
        status: ReportStatus.RESOLVED,
        payload: { period: 'last_month', generated_by: 'system' },
        createdBy: ctx.adminId,
        resolvedAt: rng.pastDate(5),
      },
      {
        type: 'content',
        title: 'مراجعة صور المنتجات المخالفة',
        status: ReportStatus.REVIEWING,
        payload: { flagged: flagged.length },
        createdBy: ctx.adminId,
      },
      {
        type: 'sellers',
        title: 'طلبات توثيق بانتظار المراجعة',
        status: ReportStatus.OPEN,
        payload: { pending: 1 },
        createdBy: ctx.adminId,
      },
    ],
  });

  await prisma.systemSetting.createMany({
    data: [
      {
        key: 'platform.commission_default_bps',
        value: 1000,
        updatedBy: ctx.adminId,
      },
      { key: 'platform.currency', value: 'SYP', updatedBy: ctx.adminId },
      {
        key: 'platform.free_shipping_above',
        value: 300000,
        updatedBy: ctx.adminId,
      },
      { key: 'platform.return_window_days', value: 7, updatedBy: ctx.adminId },
      {
        key: 'platform.payout_schedule',
        value: 'weekly',
        updatedBy: ctx.adminId,
      },
      {
        key: 'content.product_photo_ratio',
        value: '4:5',
        updatedBy: ctx.adminId,
      },
      {
        key: 'content.nsfw_check_enabled',
        value: true,
        updatedBy: ctx.adminId,
      },
      {
        key: 'auth.female_only_declaration',
        value: true,
        updatedBy: ctx.adminId,
      },
    ],
  });

  // Audit + security trail, so the admin security screens are not blank.
  for (const seller of ctx.sellers.slice(0, 5)) {
    await prisma.auditLog.create({
      data: {
        actorId: ctx.adminId,
        action: 'seller_verification.approved',
        category: 'sellers',
        outcome: 'success',
        severity: AuditSeverity.INFO,
        metadata: { seller_id: seller.id },
        createdAt: rng.pastDate(120, 10),
      },
    });
  }

  for (const customer of ctx.customers.slice(0, 6)) {
    await prisma.securityEvent.create({
      data: {
        type: SecurityEventType.LOGIN_SUCCESS,
        riskLevel: RiskLevel.LOW,
        actorId: customer.id,
        ipAddress: `31.9.${rng.int(1, 254)}.${rng.int(1, 254)}`,
        userAgent: 'Reem/1.4.0 (android)',
        createdAt: rng.pastDate(20),
      },
    });
  }

  await prisma.securityEvent.create({
    data: {
      type: SecurityEventType.SUSPICIOUS_LOGIN,
      riskLevel: RiskLevel.HIGH,
      actorId: ctx.customers[0].id,
      ipAddress: '185.203.11.42',
      userAgent: 'curl/8.4.0',
      metadata: { reason: 'محاولة دخول من دولة غير معتادة' },
      createdAt: rng.pastDate(6),
    },
  });
}

/** Push/SMS templates and one finished campaign with real deliveries. */
export async function seedNotificationOps(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;

  await prisma.notificationTemplate.createMany({
    data: [
      {
        key: 'order.shipped',
        name: 'تم شحن الطلب',
        channel: NotificationChannel.PUSH,
        title: 'طلبك في الطريق 🚚',
        body: 'طلبك رقم {{order_number}} خرج مع المندوب.',
        locale: 'ar',
      },
      {
        key: 'order.delivered',
        name: 'تم تسليم الطلب',
        channel: NotificationChannel.PUSH,
        title: 'وصل طلبك 💕',
        body: 'نتمنى أن ينال إعجابك — شاركينا رأيك بتقييم.',
        locale: 'ar',
      },
      {
        key: 'promo.flash_sale',
        name: 'عرض سريع',
        channel: NotificationChannel.PUSH,
        title: 'عرض ٢٤ ساعة ⏰',
        body: 'خصومات تصل إلى {{percent}}٪ على تشكيلة مختارة.',
        locale: 'ar',
      },
      {
        key: 'auth.otp',
        name: 'رمز التحقق',
        channel: NotificationChannel.SMS,
        title: 'رمز التحقق',
        body: 'رمزك هو {{code}} — لا تشاركيه مع أحد.',
        locale: 'ar',
      },
    ],
  });

  const campaign = await prisma.notificationCampaign.create({
    data: {
      name: 'حملة عروض نهاية الأسبوع',
      description: 'إشعار لكل المتسوقات النشطات خلال آخر ٣٠ يوم.',
      status: NotificationCampaignStatus.COMPLETED,
      channels: [NotificationChannel.PUSH, NotificationChannel.IN_APP],
      segment: { active_within_days: 30, role: 'CUSTOMER' },
      title: 'عرض نهاية الأسبوع 🌸',
      body: 'خصم يصل إلى ٣٠٪ — ينتهي الأحد.',
      deepLink: '/discovery/collections/featured',
      startedAt: rng.pastDate(9),
      completedAt: rng.pastDate(8),
      createdBy: ctx.adminId,
    },
  });

  for (const customer of ctx.customers) {
    const status = rng.weighted<NotificationDeliveryStatus>([
      [NotificationDeliveryStatus.SENT, 8],
      [NotificationDeliveryStatus.FAILED, 1],
      [NotificationDeliveryStatus.SKIPPED, 1],
    ]);
    const sentAt = rng.pastDate(8);

    const delivery = await prisma.notificationDelivery.create({
      data: {
        campaignId: campaign.id,
        userId: customer.id,
        channel: NotificationChannel.PUSH,
        status,
        provider: 'fcm',
        providerMessageId: `fcm-${customer.id.slice(0, 8)}`,
        title: 'عرض نهاية الأسبوع 🌸',
        body: 'خصم يصل إلى ٣٠٪ — ينتهي الأحد.',
        sentAt: status === NotificationDeliveryStatus.SENT ? sentAt : null,
        failedAt: status === NotificationDeliveryStatus.FAILED ? sentAt : null,
        failureReason:
          status === NotificationDeliveryStatus.FAILED
            ? 'رمز الجهاز غير صالح'
            : null,
        openedAt:
          status === NotificationDeliveryStatus.SENT && rng.bool(0.45)
            ? new Date(sentAt.getTime() + 6e5)
            : null,
        createdAt: sentAt,
      },
    });

    await prisma.notificationEvent.create({
      data: {
        deliveryId: delivery.id,
        event: status === NotificationDeliveryStatus.SENT ? 'sent' : 'failed',
        createdAt: sentAt,
      },
    });

    await prisma.pushToken.create({
      data: {
        userId: customer.id,
        tokenHash: `push-${customer.id}`,
        provider: 'fcm',
        platform: rng.pick(['android', 'ios']),
        enabled: rng.bool(0.8),
      },
    });
  }
}
