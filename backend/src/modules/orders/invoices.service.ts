import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Invoice,
  InvoiceKind,
  OrderStatus,
  Prisma,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';

type Tx = Prisma.TransactionClient;

/**
 * Who is asking for a document to be raised.
 *
 * Optional, and the absence is the meaningful case: an internal caller inside
 * a checkout or settlement transaction is the platform acting on its own
 * behalf and has already decided. A request that arrived over HTTP always
 * carries one, because issuing returns the finished document — so an
 * unauthorised issue is an unauthorised *read*, of an existing invoice as
 * readily as a new one.
 */
export interface InvoiceViewer {
  id: string;
  role: UserRole;
}

export interface IssueOptions {
  issuedById?: string | null;
  viewer?: InvoiceViewer;
}

/**
 * Statuses at which an order is settled enough to invoice.
 *
 * Q39 lets a customer change an order «قبل التجهيز», so invoicing one that is
 * still editable would produce a document the order contradicts an hour later.
 * The parent order's states are deliberately coarse — Q37's eighteen live on
 * the sub-order (Q40) — and the line that matters here is shipping: once
 * anything has left, nothing about the basket can change.
 *
 * Partial states are included: a basket where one seller has shipped and
 * another has not is still a real charge for the part that moved.
 */
const INVOICEABLE: ReadonlySet<OrderStatus> = new Set([
  OrderStatus.PARTIALLY_SHIPPED,
  OrderStatus.SHIPPED,
  OrderStatus.PARTIALLY_DELIVERED,
  OrderStatus.DELIVERED,
  OrderStatus.PARTIALLY_CANCELLED,
  OrderStatus.CLOSED,
]);

/**
 * Invoices — Q51 «الاثنين»: one for the whole order, one per seller.
 *
 * Two things shape this service.
 *
 * **It is a commercial document, not a fiscal one.** Q55 P1 answered «لا» to
 * needing a tax-compliant invoice, so there is no VAT, no legally-mandated
 * numbering sequence, no immutable fiscal register. Building those would be
 * manufacturing obligations the client does not have.
 *
 * **It stores no lines.** `OrderItem` already snapshots every line at
 * checkout — title, variant, seller, unit price, discount, total — precisely
 * so historical orders survive catalogue edits. Copying those rows into an
 * invoice table would create a second copy of the same facts with nothing
 * keeping them in step. The totals *are* frozen on the invoice, because
 * unlike the lines they can still move (Q39).
 *
 * Issuing is idempotent: asking twice returns the same document with the same
 * number, because a customer who taps twice must not end up with two invoices
 * for one purchase.
 */
@Injectable()
export class InvoicesService {
  constructor(private readonly prisma: PrismaService) {}

  /** Q51 — the customer's invoice for everything she paid. */
  async issueForOrder(
    orderId: string,
    options: IssueOptions = {},
    tx?: Tx,
  ): Promise<Invoice> {
    const db = tx ?? this.prisma;

    const order = await db.order.findUnique({
      where: { id: orderId },
      select: {
        id: true,
        userId: true,
        status: true,
        currency: true,
        fxRate: true,
        itemsSubtotal: true,
        discountTotal: true,
        shippingTotal: true,
        grandTotal: true,
      },
    });
    if (!order) throw new NotFoundException('Order not found');
    // Before `assertInvoiceable`, so a stranger cannot use the difference
    // between "not yours" and "not ready yet" to learn that an order exists.
    this.assertMayIssue(
      { kind: InvoiceKind.ORDER, customerId: order.userId, sellerId: null },
      options.viewer,
    );
    this.assertInvoiceable(order.status);

    const existing = await db.invoice.findUnique({
      where: {
        kind_subjectKey: { kind: InvoiceKind.ORDER, subjectKey: order.id },
      },
    });
    if (existing) return existing;

    return db.invoice.create({
      data: {
        number: await this.nextNumber(db, InvoiceKind.ORDER),
        kind: InvoiceKind.ORDER,
        orderId: order.id,
        subjectKey: order.id,
        currency: order.currency,
        itemsSubtotal: order.itemsSubtotal,
        discountTotal: order.discountTotal,
        shippingTotal: order.shippingTotal,
        grandTotal: order.grandTotal,
        fxRate: order.fxRate,
        issuedById: options.issuedById ?? null,
      },
    });
  }

  /**
   * Q51 — one seller's invoice for their own parcel.
   *
   * Carries the commission and the net (Q50), which the customer's copy does
   * not: what the platform took is between the platform and the seller, and
   * putting it on the customer's document would only make the total she paid
   * harder to read.
   */
  async issueForSellerOrder(
    sellerOrderId: string,
    options: IssueOptions = {},
    tx?: Tx,
  ): Promise<Invoice> {
    const db = tx ?? this.prisma;

    const sellerOrder = await db.sellerOrder.findUnique({
      where: { id: sellerOrderId },
      select: {
        id: true,
        orderId: true,
        sellerId: true,
        currency: true,
        itemsSubtotal: true,
        discountTotal: true,
        shippingCost: true,
        commissionAmount: true,
        sellerNet: true,
        order: { select: { status: true, fxRate: true, userId: true } },
      },
    });
    if (!sellerOrder) throw new NotFoundException('Sub-order not found');
    this.assertMayIssue(
      {
        kind: InvoiceKind.SELLER_ORDER,
        customerId: sellerOrder.order.userId,
        sellerId: sellerOrder.sellerId,
      },
      options.viewer,
    );
    this.assertInvoiceable(sellerOrder.order.status);

    const existing = await db.invoice.findUnique({
      where: {
        kind_subjectKey: {
          kind: InvoiceKind.SELLER_ORDER,
          subjectKey: sellerOrder.id,
        },
      },
    });
    if (existing) return existing;

    const currency = sellerOrder.currency;
    const goods = Money.of(sellerOrder.itemsSubtotal, currency);
    const discount = Money.of(sellerOrder.discountTotal, currency);
    const shipping = Money.of(sellerOrder.shippingCost, currency);

    return db.invoice.create({
      data: {
        number: await this.nextNumber(db, InvoiceKind.SELLER_ORDER),
        kind: InvoiceKind.SELLER_ORDER,
        orderId: sellerOrder.orderId,
        sellerOrderId: sellerOrder.id,
        subjectKey: sellerOrder.id,
        currency,
        itemsSubtotal: goods.toPrisma(),
        discountTotal: discount.toPrisma(),
        shippingTotal: shipping.toPrisma(),
        grandTotal: goods.minus(discount).plus(shipping).toPrisma(),
        commissionAmount: sellerOrder.commissionAmount,
        sellerNet: sellerOrder.sellerNet,
        fxRate: sellerOrder.order.fxRate,
        issuedById: options.issuedById ?? null,
      },
    });
  }

  /**
   * The document plus everything needed to render it, read from the rows that
   * were already immutable.
   */
  async render(invoiceId: string, viewer: { id: string; role: UserRole }) {
    const invoice = await this.prisma.invoice.findUnique({
      where: { id: invoiceId },
      include: {
        order: {
          select: {
            number: true,
            userId: true,
            placedAt: true,
            createdAt: true,
            recipientName: true,
            recipientPhone: true,
            governorate: true,
            city: true,
            addressLine: true,
            couponCode: true,
          },
        },
        sellerOrder: {
          select: { number: true, sellerId: true },
        },
      },
    });
    if (!invoice) throw new NotFoundException('Invoice not found');

    await this.assertMayView(invoice, viewer);

    // Lines come from the order items, which are snapshots already.
    const items = await this.prisma.orderItem.findMany({
      where: invoice.sellerOrderId
        ? { sellerOrderId: invoice.sellerOrderId }
        : { sellerOrder: { orderId: invoice.orderId } },
      orderBy: { titleSnapshot: 'asc' },
      select: {
        titleSnapshot: true,
        variantSnapshot: true,
        sellerSnapshot: true,
        currency: true,
        unitPrice: true,
        unitDiscount: true,
        quantity: true,
        lineTotal: true,
      },
    });

    const currency = invoice.currency;
    const money = (value: Prisma.Decimal | null) =>
      value === null ? null : Money.of(value, currency).toJSON();

    return {
      id: invoice.id,
      number: invoice.number,
      kind: invoice.kind,
      issued_at: invoice.issuedAt,

      order_number: invoice.order.number,
      seller_order_number: invoice.sellerOrder?.number ?? null,
      placed_at: invoice.order.placedAt ?? invoice.order.createdAt,

      // Already a snapshot on the order — never a live join to Address.
      billed_to: {
        name: invoice.order.recipientName,
        phone: invoice.order.recipientPhone,
        governorate: invoice.order.governorate,
        city: invoice.order.city,
        address_line: invoice.order.addressLine,
      },

      currency,
      fx_rate: invoice.fxRate.toString(),
      coupon_code: invoice.order.couponCode,

      lines: items.map((item) => ({
        title: item.titleSnapshot,
        variant: item.variantSnapshot,
        seller: item.sellerSnapshot,
        quantity: item.quantity,
        unit_price: Money.of(item.unitPrice, item.currency).toJSON(),
        unit_discount: Money.of(item.unitDiscount, item.currency).toJSON(),
        line_total: Money.of(item.lineTotal, item.currency).toJSON(),
      })),

      totals: {
        items_subtotal: money(invoice.itemsSubtotal),
        discount_total: money(invoice.discountTotal),
        shipping_total: money(invoice.shippingTotal),
        grand_total: money(invoice.grandTotal),
        // Only on the seller's copy.
        commission_amount: money(invoice.commissionAmount),
        seller_net: money(invoice.sellerNet),
      },
    };
  }

  /** Every invoice raised against one order — the customer's and each seller's. */
  async listForOrder(orderId: string, viewer: { id: string; role: UserRole }) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: { id: true, userId: true },
    });
    if (!order) throw new NotFoundException('Order not found');

    const isAdmin = this.isFinanceAdmin(viewer.role);
    if (!isAdmin && order.userId !== viewer.id) {
      // A seller may still hold an invoice against this order; they reach it
      // through their own sub-order, not by asking for the whole basket.
      throw new ForbiddenException('This order is not yours');
    }

    return this.prisma.invoice.findMany({
      where: { orderId },
      orderBy: { issuedAt: 'asc' },
      select: {
        id: true,
        number: true,
        kind: true,
        issuedAt: true,
        grandTotal: true,
        currency: true,
      },
    });
  }

  // ── Internals ─────────────────────────────────────────────────────────

  private assertInvoiceable(status: OrderStatus): void {
    if (!INVOICEABLE.has(status)) {
      throw new ForbiddenException(
        'This order can still be changed — it is invoiced once preparation begins',
      );
    }
  }

  /**
   * Who may read a document.
   *
   * The customer's invoice is hers; a seller's invoice is that seller's. A
   * seller must not be able to read the customer's copy — it names every other
   * seller in the basket, which Q44's privacy stance would not survive.
   */
  /**
   * Who may raise a document.
   *
   * Deliberately the same rule as `assertMayView`, because issuing hands back
   * the invoice itself: the customer's copy names every seller in her basket,
   * and a seller's copy carries the commission and the net. Without this the
   * two POST routes were an unauthenticated-by-omission read of both — a
   * seller holding one sub-order id could ask for the whole basket's totals,
   * which is exactly what `listForOrder` refuses in as many words.
   */
  private assertMayIssue(
    subject: {
      kind: InvoiceKind;
      customerId: string | null;
      sellerId: string | null;
    },
    viewer?: InvoiceViewer,
  ): void {
    if (!viewer) return;
    if (this.isFinanceAdmin(viewer.role)) return;

    if (subject.kind === InvoiceKind.SELLER_ORDER) {
      if (subject.sellerId === viewer.id) return;
      // Her own purchase; the commission is noise to her, not a secret.
      if (subject.customerId === viewer.id) return;
      throw new ForbiddenException('This invoice is not yours');
    }

    if (subject.customerId === viewer.id) return;
    throw new ForbiddenException('This invoice is not yours');
  }

  private async assertMayView(
    invoice: Invoice & {
      order: { userId: string | null };
      sellerOrder: { sellerId: string } | null;
    },
    viewer: { id: string; role: UserRole },
  ): Promise<void> {
    if (this.isFinanceAdmin(viewer.role)) return;

    if (invoice.kind === InvoiceKind.SELLER_ORDER) {
      if (invoice.sellerOrder?.sellerId === viewer.id) return;
      // The customer may read the seller's copy of her own purchase; it shows
      // the commission, which is not a secret from her, only noise.
      if (invoice.order.userId === viewer.id) return;
      throw new ForbiddenException('This invoice is not yours');
    }

    if (invoice.order.userId === viewer.id) return;
    throw new ForbiddenException('This invoice is not yours');
  }

  private isFinanceAdmin(role: UserRole): boolean {
    return (
      role === UserRole.SUPER_ADMIN ||
      role === UserRole.FINANCE_ADMIN ||
      role === UserRole.OPERATIONS_ADMIN
    );
  }

  /**
   * `INV-2026-000123` / `INS-2026-000123`.
   *
   * Counting rows is safe here because the unique index on `number` is the
   * real guard: two racing issues collide there and the loser retries rather
   * than quietly reusing a number.
   */
  private async nextNumber(db: Tx | PrismaService, kind: InvoiceKind) {
    const year = new Date().getFullYear();
    const prefix = kind === InvoiceKind.ORDER ? 'INV' : 'INS';
    const count = await db.invoice.count({ where: { kind } });
    return `${prefix}-${year}-${String(count + 1).padStart(6, '0')}`;
  }
}
