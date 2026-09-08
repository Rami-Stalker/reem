import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FlashSaleStatus, Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';
import { utcCast, utcParam } from '../../common/sql/utc-timestamp';

/** The longest a single sale may run. */
const MAX_WINDOW_DAYS = 30;

@Injectable()
export class FlashSalesService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Reading ──────────────────────────────────────────────────────────────

  /**
   * The sales a shopper can actually buy from right now.
   *
   * Live means active *and* inside its window, evaluated in the database
   * against the same UTC instant the pricing rule uses. A sale that is merely
   * `ACTIVE` may be tomorrow's.
   */
  async live(limit = 20) {
    const now = new Date();
    const rows = await this.prisma.$queryRawUnsafe<{ id: string }[]>(
      `
      SELECT s.id
      FROM flash_sales s
      WHERE s.status = $1::"FlashSaleStatus"
        AND s.starts_at <= ${utcCast('$2')}
        AND s.ends_at   >  ${utcCast('$2')}
      ORDER BY s.ends_at ASC
      LIMIT $3
      `,
      FlashSaleStatus.ACTIVE,
      utcParam(now),
      limit,
    );

    if (rows.length === 0) return [];

    const sales = await this.prisma.flashSale.findMany({
      where: { id: { in: rows.map((row) => row.id) } },
      include: {
        items: {
          include: {
            offer: {
              include: {
                seller: { select: { id: true, name: true, username: true } },
                product: {
                  select: {
                    id: true,
                    slug: true,
                    title: true,
                    media: { orderBy: { sortOrder: 'asc' }, take: 1 },
                  },
                },
              },
            },
          },
        },
      },
    });

    const order = new Map(rows.map((row, index) => [row.id, index]));
    sales.sort((a, b) => (order.get(a.id) ?? 0) - (order.get(b.id) ?? 0));

    return sales.map((sale) => this.serialize(sale, now));
  }

  async listForSeller(sellerId: string) {
    const sales = await this.prisma.flashSale.findMany({
      where: { sellerId },
      orderBy: { startsAt: 'desc' },
      include: { items: true },
    });
    return sales.map((sale) => this.serializeSummary(sale));
  }

  async listAll() {
    const sales = await this.prisma.flashSale.findMany({
      orderBy: { startsAt: 'desc' },
      take: 200,
      include: { items: true },
    });
    return sales.map((sale) => this.serializeSummary(sale));
  }

  // ── Writing ──────────────────────────────────────────────────────────────

  async create(input: {
    title: string;
    note?: string | null;
    startsAt: Date;
    endsAt: Date;
    actorId: string;
    actorRole: UserRole;
    sellerId?: string | null;
  }) {
    this.assertWindow(input.startsAt, input.endsAt);

    // A seller runs her own sale and nobody else's. Staff may run a
    // platform-wide one, or one on a named boutique's behalf.
    const sellerId =
      input.actorRole === UserRole.SELLER ? input.actorId : input.sellerId ?? null;

    const sale = await this.prisma.flashSale.create({
      data: {
        title: input.title,
        note: input.note ?? null,
        startsAt: input.startsAt,
        endsAt: input.endsAt,
        sellerId,
        createdById: input.actorId,
      },
      include: { items: true },
    });
    return this.serializeSummary(sale);
  }

  /**
   * Puts one listing in a sale.
   *
   * The sale price is checked against the offer's own price rather than
   * accepted: a "sale" that raises the price is not a sale, and a price of
   * zero is a mistake somebody would otherwise discover from the ledger.
   */
  async addItem(input: {
    saleId: string;
    offerId: string;
    salePrice: string | number;
    quantityCap?: number | null;
    fundedBySeller?: boolean;
    actorId: string;
    actorRole: UserRole;
  }) {
    const sale = await this.requireSale(input.saleId, input.actorId, input.actorRole);

    const offer = await this.prisma.sellerOffer.findUnique({
      where: { id: input.offerId },
      select: { id: true, price: true, currency: true, sellerId: true },
    });
    if (!offer) throw new NotFoundException('Offer not found');

    // A boutique's sale may only carry her own listings.
    if (sale.sellerId && offer.sellerId !== sale.sellerId) {
      throw new ForbiddenException(
        'That listing belongs to another boutique',
      );
    }
    if (input.actorRole === UserRole.SELLER && offer.sellerId !== input.actorId) {
      throw new ForbiddenException('That listing is not yours');
    }

    const salePrice = Money.of(input.salePrice, offer.currency);
    const current = Money.of(offer.price, offer.currency);

    if (salePrice.isZero()) {
      throw new BadRequestException('A sale price of zero is not a sale');
    }
    if (!salePrice.lessThan(current)) {
      throw new BadRequestException(
        `A sale price must be below the listing's own ${current.toString()}`,
      );
    }
    if (input.quantityCap !== undefined && input.quantityCap !== null && input.quantityCap < 1) {
      throw new BadRequestException('A cap of zero units is not a sale either');
    }

    const item = await this.prisma.flashSaleItem.upsert({
      where: {
        saleId_offerId: { saleId: sale.id, offerId: offer.id },
      },
      create: {
        saleId: sale.id,
        offerId: offer.id,
        salePrice: salePrice.toPrisma(),
        currency: offer.currency,
        compareAtPrice: current.toPrisma(),
        quantityCap: input.quantityCap ?? null,
        fundedBySeller: input.fundedBySeller ?? true,
      },
      update: {
        salePrice: salePrice.toPrisma(),
        compareAtPrice: current.toPrisma(),
        quantityCap: input.quantityCap ?? null,
        fundedBySeller: input.fundedBySeller ?? true,
      },
    });

    return {
      id: item.id,
      offer_id: item.offerId,
      sale_price: Money.of(item.salePrice, item.currency).toJSON(),
      compare_at: Money.of(item.compareAtPrice, item.currency).toJSON(),
      quantity_cap: item.quantityCap,
      quantity_sold: item.quantitySold,
      funded_by_seller: item.fundedBySeller,
    };
  }

  async removeItem(
    saleId: string,
    itemId: string,
    actorId: string,
    actorRole: UserRole,
  ) {
    await this.requireSale(saleId, actorId, actorRole);
    const deleted = await this.prisma.flashSaleItem.deleteMany({
      where: { id: itemId, saleId },
    });
    if (deleted.count === 0) throw new NotFoundException('Item not found');
    return { message: 'Removed from the sale' };
  }

  /**
   * Moves a sale between states.
   *
   * `PAUSED` is the stop button, and it works instantly because the pricing
   * rule reads status on every price: a sale paused at noon stops discounting
   * at noon, whatever its window says.
   */
  async setStatus(
    saleId: string,
    status: FlashSaleStatus,
    actorId: string,
    actorRole: UserRole,
  ) {
    const sale = await this.requireSale(saleId, actorId, actorRole);

    if (status === FlashSaleStatus.ACTIVE && sale.items.length === 0) {
      throw new BadRequestException(
        'A sale with nothing in it cannot go live',
      );
    }

    const updated = await this.prisma.flashSale.update({
      where: { id: saleId },
      data: { status },
      include: { items: true },
    });
    return this.serializeSummary(updated);
  }

  async remove(saleId: string, actorId: string, actorRole: UserRole) {
    const sale = await this.requireSale(saleId, actorId, actorRole);
    if (sale.status === FlashSaleStatus.ACTIVE) {
      throw new BadRequestException(
        'Pause the sale before deleting it — customers may be looking at these prices',
      );
    }
    await this.prisma.flashSale.delete({ where: { id: saleId } });
    return { message: 'Sale deleted' };
  }

  // ── internals ────────────────────────────────────────────────────────────

  private async requireSale(
    saleId: string,
    actorId: string,
    actorRole: UserRole,
  ) {
    const sale = await this.prisma.flashSale.findUnique({
      where: { id: saleId },
      include: { items: true },
    });
    if (!sale) throw new NotFoundException('Sale not found');
    if (actorRole === UserRole.SELLER && sale.sellerId !== actorId) {
      throw new ForbiddenException('That sale is not yours');
    }
    return sale;
  }

  private assertWindow(startsAt: Date, endsAt: Date) {
    if (!(endsAt > startsAt)) {
      throw new BadRequestException('A sale must end after it starts');
    }
    const days = (endsAt.getTime() - startsAt.getTime()) / 86_400_000;
    if (days > MAX_WINDOW_DAYS) {
      throw new BadRequestException(
        `A flash sale runs for at most ${MAX_WINDOW_DAYS} days — longer than that is a price change, not a sale`,
      );
    }
  }

  private serializeSummary(sale: {
    id: string;
    title: string;
    note: string | null;
    status: FlashSaleStatus;
    startsAt: Date;
    endsAt: Date;
    sellerId: string | null;
    items: { quantityCap: number | null; quantitySold: number }[];
  }) {
    return {
      id: sale.id,
      title: sale.title,
      note: sale.note,
      status: sale.status.toLowerCase(),
      starts_at: sale.startsAt.toISOString(),
      ends_at: sale.endsAt.toISOString(),
      seller_id: sale.sellerId,
      is_live: this.isLive(sale, new Date()),
      items: sale.items.length,
      units_sold: sale.items.reduce((sum, item) => sum + item.quantitySold, 0),
      units_capped: sale.items.reduce(
        (sum, item) => sum + (item.quantityCap ?? 0),
        0,
      ),
    };
  }

  private serialize(
    sale: Prisma.FlashSaleGetPayload<{
      include: {
        items: {
          include: {
            offer: {
              include: {
                seller: { select: { id: true; name: true; username: true } };
                product: {
                  select: {
                    id: true;
                    slug: true;
                    title: true;
                    media: true;
                  };
                };
              };
            };
          };
        };
      };
    }>,
    now: Date,
  ) {
    return {
      id: sale.id,
      title: sale.title,
      note: sale.note,
      starts_at: sale.startsAt.toISOString(),
      ends_at: sale.endsAt.toISOString(),
      // What a countdown on the card needs, computed once here rather than
      // from a clock the phone may have set wrong.
      seconds_remaining: Math.max(
        0,
        Math.floor((sale.endsAt.getTime() - now.getTime()) / 1000),
      ),
      items: sale.items
        // A line whose cap has filled is over, and showing it as a live price
        // would be a price the customer cannot get.
        .filter(
          (item) =>
            item.quantityCap === null || item.quantitySold < item.quantityCap,
        )
        .map((item) => ({
          offer_id: item.offerId,
          sale_price: Money.of(item.salePrice, item.currency).toJSON(),
          compare_at: Money.of(item.compareAtPrice, item.currency).toJSON(),
          units_left:
            item.quantityCap === null
              ? null
              : Math.max(0, item.quantityCap - item.quantitySold),
          seller: item.offer.seller,
          product: {
            id: item.offer.product.id,
            slug: item.offer.product.slug,
            title: item.offer.product.title,
            image: item.offer.product.media[0]?.url ?? null,
          },
        })),
    };
  }

  private isLive(
    sale: { status: FlashSaleStatus; startsAt: Date; endsAt: Date },
    now: Date,
  ): boolean {
    return (
      sale.status === FlashSaleStatus.ACTIVE &&
      sale.startsAt <= now &&
      sale.endsAt > now
    );
  }
}
