import { Injectable } from '@nestjs/common';
import { Currency, Prisma, ProductStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { LIVE_OFFER_WHERE } from '../../common/catalog/product-include';
import { Money } from '../../common/money';
import { ExchangeRateService } from '../pricing/exchange-rate.service';

/**
 * Keeps the denormalised offer roll-ups on a product true.
 *
 * `offersCount` / `minPriceSyp` / `maxPriceSyp` exist so the catalog can be
 * sorted and price-filtered in one query rather than joining every offer, and
 * so a seller pricing in USD interleaves correctly with one pricing in SYP.
 * The cost is that they must be recomputed on every offer mutation — which is
 * why this is one service every write path calls, not inline arithmetic.
 */
@Injectable()
export class CatalogRollupService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly rates: ExchangeRateService,
  ) {}

  /**
   * Recomputes a product's offer roll-ups. Pass a transaction client when
   * called from inside one so the product row and its offers commit together.
   */
  async refresh(
    productId: string,
    tx: Prisma.TransactionClient = this.prisma,
  ): Promise<void> {
    const offers = await tx.sellerOffer.findMany({
      where: { productId, ...LIVE_OFFER_WHERE },
      select: { id: true, price: true, currency: true, priceSyp: true },
    });

    if (offers.length === 0) {
      await tx.product.update({
        where: { id: productId },
        data: { offersCount: 0, minPriceSyp: null, maxPriceSyp: null },
      });
      return;
    }

    const normalised: Money[] = [];
    for (const offer of offers) {
      const syp = await this.rates.toSyp(Money.of(offer.price, offer.currency));
      normalised.push(syp);

      // Written back onto the offer, not just folded into the product's
      // min/max, because the offer ordering itself has to be currency-blind:
      // `orderBy: { price }` put a USD offer ahead of every SYP one.
      const stored = syp.toPrisma();
      if (offer.priceSyp === null || !offer.priceSyp.equals(stored)) {
        await tx.sellerOffer.update({
          where: { id: offer.id },
          data: { priceSyp: stored },
        });
      }
    }

    let min = normalised[0];
    let max = normalised[0];
    for (const price of normalised) {
      if (price.lessThan(min)) min = price;
      if (price.greaterThan(max)) max = price;
    }

    await tx.product.update({
      where: { id: productId },
      data: {
        offersCount: offers.length,
        minPriceSyp: min.toPrisma(),
        maxPriceSyp: max.toPrisma(),
      },
    });
  }

  /**
   * A canonical product is ACTIVE only while somebody actually sells it — this
   * is what keeps sold-out entries out of public browsing now that stock no
   * longer lives on the product row.
   */
  async syncStatus(
    productId: string,
    tx: Prisma.TransactionClient = this.prisma,
  ): Promise<void> {
    const product = await tx.product.findUnique({
      where: { id: productId },
      select: { status: true, offersCount: true },
    });
    if (!product) return;

    if (product.offersCount === 0 && product.status === ProductStatus.ACTIVE) {
      await tx.product.update({
        where: { id: productId },
        data: { status: ProductStatus.OUT_OF_STOCK },
      });
      return;
    }
    if (
      product.offersCount > 0 &&
      product.status === ProductStatus.OUT_OF_STOCK
    ) {
      await tx.product.update({
        where: { id: productId },
        data: { status: ProductStatus.ACTIVE },
      });
    }
  }

  async refreshAndSync(
    productId: string,
    tx: Prisma.TransactionClient = this.prisma,
  ): Promise<void> {
    await this.refresh(productId, tx);
    await this.syncStatus(productId, tx);
  }

  /** The SYP-normalised value of an offer price, for comparison and reports. */
  toSyp(amount: Prisma.Decimal, currency: Currency): Promise<Money> {
    return this.rates.toSyp(Money.of(amount, currency));
  }
}
