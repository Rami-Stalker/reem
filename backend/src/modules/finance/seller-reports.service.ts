import { Injectable } from '@nestjs/common';
import { CommissionStatus, Currency, PayoutStatus, Prisma } from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';

interface LedgerMonthRow {
  month: Date;
  orders: bigint;
  gross: Prisma.Decimal | null;
  commission: Prisma.Decimal | null;
  platform_fee: Prisma.Decimal | null;
  net: Prisma.Decimal | null;
  reversed_count: bigint;
  reversed_gross: Prisma.Decimal | null;
}

interface PayoutMonthRow {
  month: Date;
  paid: Prisma.Decimal | null;
  count: bigint;
}

/**
 * «التقارير المالية» — her money month by month.
 *
 * Not the statement (that is «أرباحي», movement by movement) and not the
 * withdrawals (that is «مركز السحب»): the view an accountant asks for. Each
 * month is read from the commission ledger, which is the settled record of
 * every sale — what she sold, what the platform kept, what is hers — beside
 * what was reversed and what was actually paid out to her.
 *
 * Months are Damascus months: a sale at 1am on the 1st belongs to the new
 * month for her, whatever UTC says.
 */
@Injectable()
export class SellerReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async monthly(
    sellerId: string,
    currency: Currency = Currency.SYP,
    months = 12,
  ) {
    const span = Math.min(Math.max(Math.trunc(months), 1), 24);
    const zone = 'Asia/Damascus';
    const since = Prisma.sql`date_trunc('month', (now() AT TIME ZONE ${zone})) - make_interval(months => ${span - 1}::int)`;
    const monthOf = (column: Prisma.Sql) =>
      Prisma.sql`date_trunc('month', (${column} AT TIME ZONE 'UTC' AT TIME ZONE ${zone}))`;

    const [ledgerRows, payoutRows] = await Promise.all([
      this.prisma.$queryRaw<LedgerMonthRow[]>`
        SELECT ${monthOf(Prisma.sql`created_at`)} AS month,
               count(*) FILTER (WHERE status <> ${CommissionStatus.REVERSED}::"CommissionStatus") AS orders,
               sum(gross) FILTER (WHERE status <> ${CommissionStatus.REVERSED}::"CommissionStatus") AS gross,
               sum(commission) FILTER (WHERE status <> ${CommissionStatus.REVERSED}::"CommissionStatus") AS commission,
               sum(platform_fee) FILTER (WHERE status <> ${CommissionStatus.REVERSED}::"CommissionStatus") AS platform_fee,
               sum(net) FILTER (WHERE status <> ${CommissionStatus.REVERSED}::"CommissionStatus") AS net,
               count(*) FILTER (WHERE status = ${CommissionStatus.REVERSED}::"CommissionStatus") AS reversed_count,
               sum(gross) FILTER (WHERE status = ${CommissionStatus.REVERSED}::"CommissionStatus") AS reversed_gross
          FROM commission_ledgers
         WHERE seller_id = ${sellerId}::uuid
           AND currency = ${currency}::"Currency"
           AND ${monthOf(Prisma.sql`created_at`)} >= ${since}
         GROUP BY 1`,
      this.prisma.$queryRaw<PayoutMonthRow[]>`
        SELECT ${monthOf(Prisma.sql`paid_at`)} AS month,
               sum(net) AS paid,
               count(*) AS count
          FROM seller_payouts
         WHERE seller_id = ${sellerId}::uuid
           AND currency = ${currency}::"Currency"
           AND status = ${PayoutStatus.PAID}::"PayoutStatus"
           AND paid_at IS NOT NULL
           AND ${monthOf(Prisma.sql`paid_at`)} >= ${since}
         GROUP BY 1`,
    ]);

    const key = (date: Date) =>
      `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
    const ledgers = new Map(ledgerRows.map((row) => [key(row.month), row]));
    const payouts = new Map(payoutRows.map((row) => [key(row.month), row]));
    const money = (value: Prisma.Decimal | null | undefined) =>
      Money.of(value ?? 0, currency);

    // Every month in the span, empty ones included, newest first — a gap is
    // information too.
    const now = damascusNow();
    const rows = Array.from({ length: span }, (_, back) => {
      const year = now.year + Math.floor((now.month - back) / 12);
      const monthIndex = (((now.month - back) % 12) + 12) % 12;
      const id = `${year}-${String(monthIndex + 1).padStart(2, '0')}`;
      const ledger = ledgers.get(id);
      const payout = payouts.get(id);
      return {
        month: id,
        orders: Number(ledger?.orders ?? 0),
        gross: money(ledger?.gross),
        commission: money(ledger?.commission),
        platform_fees: money(ledger?.platform_fee),
        net: money(ledger?.net),
        reversed_orders: Number(ledger?.reversed_count ?? 0),
        reversed: money(ledger?.reversed_gross),
        paid_out: money(payout?.paid),
        payouts: Number(payout?.count ?? 0),
      };
    });

    const total = (pick: (row: (typeof rows)[number]) => Money) =>
      rows.reduce((sum, row) => sum.plus(pick(row)), Money.zero(currency));

    return {
      currency,
      months: rows.map((row) => ({
        ...row,
        gross: row.gross.toJSON(),
        commission: row.commission.toJSON(),
        platform_fees: row.platform_fees.toJSON(),
        net: row.net.toJSON(),
        reversed: row.reversed.toJSON(),
        paid_out: row.paid_out.toJSON(),
      })),
      totals: {
        orders: rows.reduce((sum, row) => sum + row.orders, 0),
        gross: total((row) => row.gross).toJSON(),
        commission: total((row) => row.commission).toJSON(),
        platform_fees: total((row) => row.platform_fees).toJSON(),
        net: total((row) => row.net).toJSON(),
        reversed: total((row) => row.reversed).toJSON(),
        paid_out: total((row) => row.paid_out).toJSON(),
      },
    };
  }
}

/** The current year and zero-based month on a Damascus calendar. */
function damascusNow(): { year: number; month: number } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Damascus',
    year: 'numeric',
    month: '2-digit',
  }).formatToParts(new Date());
  const year = Number(parts.find((p) => p.type === 'year')?.value);
  const month = Number(parts.find((p) => p.type === 'month')?.value) - 1;
  return { year, month };
}
