import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OfferStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { assertCanManage } from '../../common/authz';
import { buildMeta } from '../../common/dto/pagination.dto';
import { OFFER_INCLUDE } from '../../common/catalog/product-include';
import { Money } from '../../common/money';
import { serializeOffer, serializeProduct } from '../../common/serializers';
import { PRODUCT_CARD_INCLUDE } from '../../common/catalog/product-include';
import { CatalogRollupService } from './catalog-rollup.service';
import { FavoritesService } from '../favorites/favorites.service';
import {
  AdjustOfferStockDto,
  CreateOfferDto,
  OfferVariantPriceDto,
  UpdateOfferDto,
} from './dto/offer.dto';
import { SellerProductQueryDto } from './dto/seller-product-query.dto';

const Decimal = Prisma.Decimal;

/**
 * A seller's listings.
 *
 * This is the layer the old `SellerProductsService` conflated with the catalog:
 * a seller does not own a product, they own an *offer* on one. Price, stock,
 * currency, handling time and return policy all live here, which is what lets
 * several sellers list the same item at different prices (Q23/Q27 P2).
 */
@Injectable()
export class SellerOffersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly rollup: CatalogRollupService,
    private readonly favorites: FavoritesService,
  ) {}

  async create(user: AuthUser, dto: CreateOfferDto) {
    const product = await this.prisma.product.findUnique({
      where: { id: dto.product_id },
      select: { id: true },
    });
    if (!product) throw new NotFoundException('Product not found');

    const existing = await this.prisma.sellerOffer.findUnique({
      where: { productId_sellerId: { productId: dto.product_id, sellerId: user.id } },
      select: { id: true },
    });
    if (existing) {
      throw new ConflictException(
        'You already list this product — edit your existing offer instead',
      );
    }

    const offer = await this.prisma.$transaction(async (tx) => {
      const created = await tx.sellerOffer.create({
        data: {
          product: { connect: { id: dto.product_id } },
          seller: { connect: { id: user.id } },
          ...this.priceData(dto),
          variants: dto.variants?.length
            ? { create: await this.variantRows(tx, dto.product_id, dto.variants) }
            : undefined,
        },
        include: OFFER_INCLUDE,
      });
      await this.rollup.refreshAndSync(dto.product_id, tx);
      return created;
    });

    return serializeOffer(offer);
  }

  async update(user: AuthUser, offerId: string, dto: UpdateOfferDto) {
    const current = await this.ownedOrThrow(user, offerId);

    const data: Prisma.SellerOfferUpdateInput = {
      ...(dto.currency !== undefined && { currency: dto.currency }),
      ...(dto.price !== undefined && { price: this.decimal(dto.price, 'price') }),
      ...(dto.compare_at_price !== undefined && {
        compareAtPrice: this.decimal(dto.compare_at_price, 'compare_at_price'),
      }),
      ...(dto.wholesale_price !== undefined && {
        wholesalePrice: this.decimal(dto.wholesale_price, 'wholesale_price'),
      }),
      ...(dto.wholesale_min_qty !== undefined && {
        wholesaleMinQty: dto.wholesale_min_qty,
      }),
      ...(dto.stock !== undefined && { stock: dto.stock }),
      ...(dto.min_order_qty !== undefined && { minOrderQty: dto.min_order_qty }),
      ...(dto.max_order_qty !== undefined && { maxOrderQty: dto.max_order_qty }),
      ...(dto.sku !== undefined && { sku: dto.sku }),
      ...(dto.handling_days !== undefined && { handlingDays: dto.handling_days }),
      ...(dto.is_made_to_order !== undefined && {
        isMadeToOrder: dto.is_made_to_order,
      }),
      ...(dto.requires_deposit !== undefined && {
        requiresDeposit: dto.requires_deposit,
      }),
      ...(dto.accepts_returns !== undefined && {
        acceptsReturns: dto.accepts_returns,
      }),
      ...(dto.status !== undefined && { status: dto.status }),
    };

    const offer = await this.prisma.$transaction(async (tx) => {
      if (dto.variants?.length) {
        await tx.sellerOfferVariant.deleteMany({ where: { offerId } });
        await tx.sellerOfferVariant.createMany({
          data: (
            await this.variantRows(tx, current.productId, dto.variants)
          ).map((row) => ({ ...row, offerId })),
        });
      }
      const updated = await tx.sellerOffer.update({
        where: { id: offerId },
        data: this.withDerivedStatus(data, current.status, dto.stock),
        include: OFFER_INCLUDE,
      });
      await this.rollup.refreshAndSync(current.productId, tx);
      return updated;
    });

    await this.notifyWatchers(current, offer);
    return serializeOffer(offer);
  }

  async adjustStock(user: AuthUser, offerId: string, dto: AdjustOfferStockDto) {
    const current = await this.ownedOrThrow(user, offerId);

    if (dto.variant_id) {
      const variantRow = await this.prisma.sellerOfferVariant.findUnique({
        where: { offerId_variantId: { offerId, variantId: dto.variant_id } },
      });
      if (!variantRow) throw new NotFoundException('Variant is not on this offer');
      await this.prisma.sellerOfferVariant.update({
        where: { id: variantRow.id },
        data: { stock: Math.max(0, variantRow.stock + dto.delta) },
      });
    }

    const newStock = Math.max(0, current.stock + dto.delta);
    const offer = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.sellerOffer.update({
        where: { id: offerId },
        data: this.withDerivedStatus({ stock: newStock }, current.status, newStock),
        include: OFFER_INCLUDE,
      });
      await this.rollup.refreshAndSync(current.productId, tx);
      return updated;
    });

    if (current.stock === 0 && newStock > 0) {
      await this.favorites.notifyBackInStock(current.productId);
    }
    return serializeOffer(offer);
  }

  async remove(user: AuthUser, offerId: string) {
    const current = await this.ownedOrThrow(user, offerId);

    // Offers are archived rather than deleted: order history snapshots point
    // back at them for dispute evidence.
    await this.prisma.$transaction(async (tx) => {
      await tx.sellerOffer.update({
        where: { id: offerId },
        data: { status: OfferStatus.ARCHIVED, isActive: false },
      });
      await this.rollup.refreshAndSync(current.productId, tx);
    });

    return { message: 'Offer archived' };
  }

  async listMine(user: AuthUser, query: SellerProductQueryDto) {
    const where: Prisma.SellerOfferWhereInput = {
      sellerId: user.id,
      ...(query.status ? { status: this.offerStatusFor(query.status) } : {}),
      ...(query.q
        ? {
            product: {
              OR: [
                { title: { contains: query.q, mode: 'insensitive' } },
                { description: { contains: query.q, mode: 'insensitive' } },
              ],
            },
          }
        : {}),
    };

    const [offers, total] = await Promise.all([
      this.prisma.sellerOffer.findMany({
        where,
        orderBy: this.orderBy(query.sort),
        skip: query.skip,
        take: query.limit,
        include: { ...OFFER_INCLUDE, product: { include: PRODUCT_CARD_INCLUDE } },
      }),
      this.prisma.sellerOffer.count({ where }),
    ]);

    return {
      data: offers.map((offer) => ({
        ...serializeOffer(offer),
        product: serializeProduct(offer.product),
      })),
      pagination: buildMeta(query.page, query.limit, total, offers.length),
    };
  }

  async getMine(user: AuthUser, offerId: string) {
    await this.ownedOrThrow(user, offerId);
    const offer = await this.prisma.sellerOffer.findUnique({
      where: { id: offerId },
      include: { ...OFFER_INCLUDE, product: { include: PRODUCT_CARD_INCLUDE } },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    return {
      ...serializeOffer(offer),
      product: serializeProduct(offer.product),
    };
  }

  /** Low-stock alerts for the seller dashboard (Q69 P1). */
  async lowStock(user: AuthUser, threshold = 5) {
    const offers = await this.prisma.sellerOffer.findMany({
      where: {
        sellerId: user.id,
        status: { in: [OfferStatus.ACTIVE, OfferStatus.OUT_OF_STOCK] },
        stock: { lte: threshold },
      },
      orderBy: { stock: 'asc' },
      take: 50,
      include: { ...OFFER_INCLUDE, product: { include: PRODUCT_CARD_INCLUDE } },
    });

    return offers.map((offer) => ({
      ...serializeOffer(offer),
      product: serializeProduct(offer.product),
    }));
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  private async ownedOrThrow(user: AuthUser, offerId: string) {
    const offer = await this.prisma.sellerOffer.findUnique({
      where: { id: offerId },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    assertCanManage(offer.sellerId, user);
    return offer;
  }

  private priceData(
    dto: CreateOfferDto,
  ): Omit<Prisma.SellerOfferCreateInput, 'product' | 'seller' | 'variants'> {
    const price = this.decimal(dto.price, 'price');
    if (price.lessThanOrEqualTo(0)) {
      throw new BadRequestException('Price must be greater than zero');
    }
    if (dto.wholesale_price && !dto.wholesale_min_qty) {
      throw new BadRequestException(
        'A wholesale price requires a minimum wholesale quantity',
      );
    }

    return {
      currency: dto.currency,
      price,
      compareAtPrice: dto.compare_at_price
        ? this.decimal(dto.compare_at_price, 'compare_at_price')
        : null,
      wholesalePrice: dto.wholesale_price
        ? this.decimal(dto.wholesale_price, 'wholesale_price')
        : null,
      wholesaleMinQty: dto.wholesale_min_qty ?? null,
      stock: dto.stock,
      minOrderQty: dto.min_order_qty ?? 1,
      maxOrderQty: dto.max_order_qty ?? null,
      sku: dto.sku ?? null,
      handlingDays: dto.handling_days ?? 1,
      isMadeToOrder: dto.is_made_to_order ?? false,
      requiresDeposit: dto.requires_deposit ?? false,
      depositPercent: dto.deposit_percent
        ? this.decimal(dto.deposit_percent, 'deposit_percent')
        : null,
      acceptsReturns: dto.accepts_returns ?? true,
    };
  }

  /** Keeps `status` coherent with stock without the caller having to remember. */
  private withDerivedStatus(
    data: Prisma.SellerOfferUpdateInput,
    currentStatus: OfferStatus,
    nextStock: number | undefined,
  ): Prisma.SellerOfferUpdateInput {
    if (nextStock === undefined || data.status !== undefined) return data;
    if (nextStock === 0 && currentStatus === OfferStatus.ACTIVE) {
      return { ...data, status: OfferStatus.OUT_OF_STOCK };
    }
    if (nextStock > 0 && currentStatus === OfferStatus.OUT_OF_STOCK) {
      return { ...data, status: OfferStatus.ACTIVE };
    }
    return data;
  }

  private async variantRows(
    tx: Prisma.TransactionClient,
    productId: string,
    variants: OfferVariantPriceDto[],
  ) {
    const canonical = await tx.productVariant.findMany({
      where: { productId },
      select: { id: true },
    });
    const known = new Set(canonical.map((variant) => variant.id));

    return variants.map((variant) => {
      if (!known.has(variant.variant_id)) {
        throw new BadRequestException(
          `Variant ${variant.variant_id} does not belong to this product`,
        );
      }
      return {
        variantId: variant.variant_id,
        price: variant.price ? this.decimal(variant.price, 'variant price') : null,
        stock: variant.stock,
        sku: variant.sku ?? null,
      };
    });
  }

  private async notifyWatchers(
    before: { productId: string; price: Prisma.Decimal; stock: number },
    after: { price: Prisma.Decimal; stock: number },
  ) {
    if (after.price.lessThan(before.price)) {
      await this.favorites.notifyPriceDrop(
        before.productId,
        before.price,
        after.price,
      );
    }
    if (before.stock === 0 && after.stock > 0) {
      await this.favorites.notifyBackInStock(before.productId);
    }
  }

  private decimal(value: string, field: string): Prisma.Decimal {
    try {
      const parsed = new Decimal(value);
      if (parsed.isNegative()) {
        throw new BadRequestException(`${field} cannot be negative`);
      }
      return parsed;
    } catch {
      throw new BadRequestException(`${field} is not a valid amount`);
    }
  }

  private offerStatusFor(status: string): OfferStatus | undefined {
    const upper = status.toUpperCase();
    return (OfferStatus as Record<string, OfferStatus>)[upper];
  }

  private orderBy(sort?: string): Prisma.SellerOfferOrderByWithRelationInput[] {
    switch (sort) {
      case 'oldest':
        return [{ createdAt: 'asc' }];
      case 'price_asc':
        return [{ price: 'asc' }];
      case 'price_desc':
        return [{ price: 'desc' }];
      case 'best_selling':
        return [{ product: { ordersCount: 'desc' } }];
      case 'top_rated':
        return [{ product: { rating: 'desc' } }];
      default:
        return [{ createdAt: 'desc' }];
    }
  }
}
