import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import {
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  PointsTransactionType,
  Prisma,
  WalletTransactionSource,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';
import { WalletService } from '../ledger/wallet.service';

type Tx = Prisma.TransactionClient;

/**
 * Q43, verbatim: «كل 10,000 ل.س من قيمة المشتريات المكتملة = نقطة ولاء،
 * وكل 10 نقاط = 5,000 ل.س رصيد يُستخدم داخل المنصة، مع احتساب النقاط بعد
 * انتهاء مدة الاسترجاع».
 *
 * Both rates are stated in SYP because the client stated them in SYP. An order
 * priced in USD accrues nothing until someone decides the USD rate — which is
 * a business decision, not one to guess at in code.
 */
/// In **new** Syrian pounds. Q43's figures — 10,000 ل.س a point, 10 points for
/// 5,000 ل.س — were stated in the old lira; dropping the two zeros keeps the
/// programme worth exactly what the client priced it at.
export const SYP_PER_POINT = 100;
export const POINTS_PER_REDEMPTION = 10;
export const SYP_PER_REDEMPTION = 50;

/**
 * How many points a spend of [spend] is worth — Q43's rate, as a plain
 * function so that the write paths outside this module can use it without
 * taking the whole service (and its ledger) as a dependency.
 *
 * Checkout used to award `Math.floor(total)` — one point per pound — which is
 * ten thousand times this rate. On an order of 118,000 ل.س that minted 118,000
 * points against a catalogue whose dearest reward costs 1,200, so a single
 * purchase bought out the entire rewards programme several hundred times over.
 */
export function pointsForSpend(spend: Money): number {
  if (spend.currency !== Currency.SYP) return 0;
  return Math.floor(Number(spend.toJSON().amount) / SYP_PER_POINT);
}

/**
 * Loyalty points, and the money behind them.
 *
 * Points look like a marketing feature and are in fact a liability: once
 * awarded they are a promise of future discount that the platform will have to
 * honour. `LOYALTY_LIABILITY` carries that promise, so the balance sheet
 * reflects what has been committed rather than only what has been spent.
 *
 * Three things happen here and each has a ledger consequence:
 *
 * - **Accrual** (after the return window, per Q43) books the cost now:
 *   promotion expense up, loyalty liability up.
 * - **Conversion** to wallet credit moves one liability into another —
 *   nothing enters or leaves the platform.
 * - **Expiry** releases the liability back, because the promise lapsed.
 *
 * Note this deliberately does not touch `PointsService`, whose own
 * `POINTS_PER_UNIT = 100` coupon-based redemption predates the client's Q43
 * answer and uses different rates. The two need reconciling as a product
 * decision; this service is the one that matches what the client asked for.
 */
@Injectable()
export class LoyaltyService {
  private readonly logger = new Logger(LoyaltyService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly wallets: WalletService,
  ) {}

  /** How many points a completed purchase is worth (Q43). */
  pointsFor(spend: Money): number {
    return pointsForSpend(spend);
  }

  /** What a number of points is worth as wallet credit (Q43). */
  creditFor(points: number): Money {
    const redemptions = Math.floor(points / POINTS_PER_REDEMPTION);
    return Money.of(
      String(redemptions * SYP_PER_REDEMPTION),
      Currency.SYP,
    );
  }

  /**
   * Q43 — «مع احتساب النقاط بعد انتهاء مدة الاسترجاع».
   *
   * Awards points for a sub-order once its return window has closed. Called by
   * the same sweep that releases escrow, so a customer earns points at the
   * moment the sale becomes final rather than when she pays.
   */
  async accrueForSellerOrder(
    sellerOrderId: string,
    tx?: Tx,
  ): Promise<number> {
    const db = tx ?? this.prisma;
    const sellerOrder = await db.sellerOrder.findUnique({
      where: { id: sellerOrderId },
      select: {
        id: true,
        number: true,
        orderId: true,
        currency: true,
        itemsSubtotal: true,
        order: { select: { userId: true } },
      },
    });
    if (!sellerOrder) return 0;

    const customerId = sellerOrder.order.userId;
    // A guest checkout (Q46 P1) has no account to hold points.
    if (!customerId) return 0;

    const spend = Money.of(sellerOrder.itemsSubtotal, sellerOrder.currency);
    const points = this.pointsFor(spend);
    if (points <= 0) return 0;

    const reference = `loyalty-accrue:${sellerOrderId}`;
    const already = await db.journalEntry.findUnique({
      where: { reference },
      select: { id: true },
    });
    if (already) return 0;

    // The points are worth this much if every one is eventually redeemed.
    const liability = this.pointValue(points);

    const run = async (inner: Tx): Promise<void> => {
      const user = await inner.user.update({
        where: { id: customerId },
        data: {
          points: { increment: points },
          lifetimePoints: { increment: points },
        },
        select: { points: true },
      });

      await inner.pointsTransaction.create({
        data: {
          userId: customerId,
          type: PointsTransactionType.EARN,
          points,
          reason: `نقاط عن الطلب ${sellerOrder.number}`,
          orderId: sellerOrder.orderId,
          balanceAfter: user.points,
        },
      });

      if (!liability.isZero()) {
        await this.ledger.post(
          {
            type: JournalEntryType.LOYALTY_ACCRUED,
            reference,
            description: `Loyalty points earned — ${sellerOrder.number}`,
            orderId: sellerOrder.orderId,
            sellerOrderId: sellerOrder.id,
            lines: [
              {
                account: {
                  code: LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE,
                },
                direction: LedgerDirection.DEBIT,
                amount: liability,
                memo: `${points} point(s)`,
              },
              {
                account: { code: LedgerAccountCode.LOYALTY_LIABILITY },
                direction: LedgerDirection.CREDIT,
                amount: liability,
              },
            ],
            metadata: {
              user_id: customerId,
              points,
            } as Prisma.InputJsonValue,
          },
          inner,
        );
      }
    };

    if (tx) await run(tx);
    else await this.prisma.$transaction(run);

    return points;
  }

  /**
   * Q43 — «كل 10 نقاط = 5,000 ل.س رصيد يُستخدم داخل المنصة».
   *
   * Converts points into spendable wallet credit. The wallet's
   * `POINTS_CONVERSION` source already books this as loyalty liability down,
   * wallet liability up, so nothing is created here — a promise simply
   * becomes a balance.
   */
  async convertToWallet(userId: string, points: number, tx?: Tx) {
    const db = tx ?? this.prisma;
    if (!Number.isInteger(points) || points <= 0) {
      throw new BadRequestException('Points must be a positive whole number');
    }
    if (points % POINTS_PER_REDEMPTION !== 0) {
      throw new BadRequestException(
        `Points convert in multiples of ${POINTS_PER_REDEMPTION}`,
      );
    }

    const user = await db.user.findUnique({
      where: { id: userId },
      select: { points: true },
    });
    if (!user || user.points < points) {
      throw new BadRequestException(
        `Not enough points: have ${user?.points ?? 0}, need ${points}`,
      );
    }

    const credit = this.creditFor(points);
    if (credit.isZero()) {
      throw new BadRequestException('That many points are worth nothing yet');
    }

    const run = async (inner: Tx) => {
      // The balance check above ran against a read that is already stale — and
      // when no transaction was handed in, it ran outside this one entirely.
      // Two conversions of the same 10 points therefore both passed it, both
      // decremented, and the customer walked away with twice the wallet credit
      // and a negative points balance. Points are a liability the platform
      // pays out in real money, so this is not a counter drifting.
      //
      // The condition moves into the UPDATE, where Postgres re-checks it
      // against the locked row: the second conversion matches no rows and is
      // refused with the same message it would have got a moment earlier.
      const claimed = await inner.user.updateMany({
        where: { id: userId, points: { gte: points } },
        data: { points: { decrement: points } },
      });
      if (claimed.count === 0) {
        const current = await inner.user.findUnique({
          where: { id: userId },
          select: { points: true },
        });
        throw new BadRequestException(
          `Not enough points: have ${current?.points ?? 0}, need ${points}`,
        );
      }
      // Safe to re-read: our own UPDATE holds the row until this transaction
      // commits, so nobody can move the balance underneath us.
      const updated = await inner.user.findUniqueOrThrow({
        where: { id: userId },
        select: { points: true },
      });

      const record = await inner.pointsTransaction.create({
        data: {
          userId,
          type: PointsTransactionType.REDEEM,
          points: -points,
          reason: `تحويل ${points} نقطة إلى رصيد المحفظة`,
          balanceAfter: updated.points,
        },
      });

      const movement = await this.wallets.credit(
        {
          userId,
          amount: credit,
          source: WalletTransactionSource.POINTS_CONVERSION,
          reason: `تحويل ${points} نقطة ولاء`,
          reference: `loyalty-convert:${record.id}`,
        },
        inner,
      );

      return {
        points_converted: points,
        points_remaining: updated.points,
        credited: credit.toJSON(),
        wallet_balance: Money.of(
          movement.balanceAfter,
          credit.currency,
        ).toJSON(),
      };
    };

    if (tx) return run(tx);
    return this.prisma.$transaction(run);
  }

  /**
   * The money value carried by a number of points.
   *
   * Uses the *redemption* rate, not the earn rate: 10 points buy 5,000 SYP of
   * credit, so 10 points are a 5,000 SYP obligation. Valuing them at the
   * 10,000-per-point earn rate would overstate the liability twentyfold.
   */
  private pointValue(points: number): Money {
    const perPoint = SYP_PER_REDEMPTION / POINTS_PER_REDEMPTION;
    return Money.of(String(points * perPoint), Currency.SYP);
  }
}
