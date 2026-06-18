import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MediaType, Prisma, ProductStatus } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { assertCanManage } from '../../common/authz';
import { buildMeta } from '../../common/dto/pagination.dto';
import { serializeProduct, serializeVariant } from '../../common/serializers';
import { ProductsRepository } from './products.repository';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import {
  ProductSort,
  SellerProductQueryDto,
} from './dto/seller-product-query.dto';
import { CreateVariantDto, UpdateVariantDto } from './dto/product-variant.dto';
import { FavoritesService } from '../favorites/favorites.service';

@Injectable()
export class SellerProductsService {
  constructor(
    private readonly repo: ProductsRepository,
    private readonly favorites: FavoritesService,
  ) {}

  async create(user: AuthUser, dto: CreateProductDto) {
    const product = await this.repo.create({
      seller: { connect: { id: user.id } },
      title: dto.title.trim(),
      description: dto.description,
      category: dto.category.toLowerCase().trim(),
      price: dto.price,
      oldPrice: dto.old_price ?? null,
      stock: dto.stock ?? 0,
      status: dto.status ?? ProductStatus.DRAFT,
      isFeatured: dto.is_featured ?? false,
      showInFeed: dto.show_in_feed ?? true,
      media: dto.media?.length
        ? {
            create: dto.media.map((m, i) => ({
              url: m.url,
              type: m.type ?? MediaType.image,
              sortOrder: m.sort_order ?? i,
            })),
          }
        : undefined,
      variants: dto.variants?.length
        ? {
            create: dto.variants.map((v, i) => ({
              name: v.name,
              sku: v.sku ?? null,
              price: v.price ?? null,
              stock: v.stock ?? 0,
              attributes: (v.attributes as Prisma.InputJsonValue) ?? Prisma.JsonNull,
              sortOrder: v.sort_order ?? i,
            })),
          }
        : undefined,
    });
    return serializeProduct(product);
  }

  async update(user: AuthUser, id: string, dto: UpdateProductDto) {
    const current = await this.ownedOrThrow(user, id);

    const data: Prisma.ProductUpdateInput = {
      ...(dto.title !== undefined && { title: dto.title.trim() }),
      ...(dto.description !== undefined && { description: dto.description }),
      ...(dto.category !== undefined && {
        category: dto.category.toLowerCase().trim(),
      }),
      ...(dto.price !== undefined && { price: dto.price }),
      ...(dto.old_price !== undefined && { oldPrice: dto.old_price }),
      ...(dto.stock !== undefined && { stock: dto.stock }),
      ...(dto.status !== undefined && { status: dto.status }),
      ...(dto.is_featured !== undefined && { isFeatured: dto.is_featured }),
      ...(dto.show_in_feed !== undefined && { showInFeed: dto.show_in_feed }),
      // Replace the gallery wholesale when provided.
      ...(dto.media !== undefined && {
        media: {
          deleteMany: {},
          create: dto.media.map((m, i) => ({
            url: m.url,
            type: m.type ?? MediaType.image,
            sortOrder: m.sort_order ?? i,
          })),
        },
      }),
    };

    const product = await this.repo.update(id, data);
    if (dto.price !== undefined && dto.price < current.price) {
      await this.favorites.notifyPriceDrop(id, current.price, dto.price);
    }
    if (dto.stock !== undefined && current.stock === 0 && dto.stock > 0) {
      await this.favorites.notifyBackInStock(id);
    }
    return serializeProduct(product);
  }

  async remove(user: AuthUser, id: string) {
    await this.ownedOrThrow(user, id);
    await this.repo.delete(id);
    return { message: 'Product deleted' };
  }

  async setStatus(user: AuthUser, id: string, status: ProductStatus) {
    await this.ownedOrThrow(user, id);
    const product = await this.repo.update(id, { status });
    return serializeProduct(product);
  }

  async adjustStock(user: AuthUser, id: string, delta: number) {
    const current = await this.ownedOrThrow(user, id);
    const newStock = Math.max(0, current.stock + delta);

    const data: Prisma.ProductUpdateInput = { stock: newStock };
    // Keep status coherent with availability.
    if (newStock === 0 && current.status === ProductStatus.ACTIVE) {
      data.status = ProductStatus.OUT_OF_STOCK;
    } else if (newStock > 0 && current.status === ProductStatus.OUT_OF_STOCK) {
      data.status = ProductStatus.ACTIVE;
    }

    const product = await this.repo.update(id, data);
    if (current.stock === 0 && newStock > 0) {
      await this.favorites.notifyBackInStock(id);
    }
    return serializeProduct(product);
  }

  async listMine(user: AuthUser, query: SellerProductQueryDto) {
    const where: Prisma.ProductWhereInput = {
      sellerId: user.id,
      ...(query.status ? { status: query.status } : {}),
      ...(query.q
        ? {
            OR: [
              { title: { contains: query.q, mode: 'insensitive' } },
              { description: { contains: query.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [products, total] = await Promise.all([
      this.repo.list({
        where,
        orderBy: this.orderBy(query.sort),
        skip: query.skip,
        take: query.limit,
      }),
      this.repo.count(where),
    ]);

    return {
      data: products.map((p) => serializeProduct(p)),
      pagination: buildMeta(query.page, query.limit, total, products.length),
    };
  }

  async getMine(user: AuthUser, id: string) {
    await this.ownedOrThrow(user, id);
    const product = await this.repo.findById(id);
    return serializeProduct(product!);
  }

  // ── Variants ──────────────────────────────────────────────────────────

  async addVariant(user: AuthUser, productId: string, dto: CreateVariantDto) {
    await this.ownedOrThrow(user, productId);
    const variant = await this.repo.createVariant({
      product: { connect: { id: productId } },
      name: dto.name,
      sku: dto.sku ?? null,
      price: dto.price ?? null,
      stock: dto.stock ?? 0,
      attributes: (dto.attributes as Prisma.InputJsonValue) ?? Prisma.JsonNull,
      sortOrder: dto.sort_order ?? 0,
    });
    return serializeVariant(variant);
  }

  async updateVariant(
    user: AuthUser,
    productId: string,
    variantId: string,
    dto: UpdateVariantDto,
  ) {
    await this.ownedOrThrow(user, productId);
    await this.variantOrThrow(productId, variantId);

    const variant = await this.repo.updateVariant(variantId, {
      ...(dto.name !== undefined && { name: dto.name }),
      ...(dto.sku !== undefined && { sku: dto.sku }),
      ...(dto.price !== undefined && { price: dto.price }),
      ...(dto.stock !== undefined && { stock: dto.stock }),
      ...(dto.attributes !== undefined && {
        attributes: dto.attributes as Prisma.InputJsonValue,
      }),
      ...(dto.sort_order !== undefined && { sortOrder: dto.sort_order }),
    });
    return serializeVariant(variant);
  }

  async removeVariant(user: AuthUser, productId: string, variantId: string) {
    await this.ownedOrThrow(user, productId);
    await this.variantOrThrow(productId, variantId);
    await this.repo.deleteVariant(variantId);
    return { message: 'Variant deleted' };
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  private async ownedOrThrow(user: AuthUser, id: string) {
    const owner = await this.repo.findOwner(id);
    if (!owner) throw new NotFoundException('Product not found');
    assertCanManage(owner.sellerId, user);
    return owner;
  }

  private async variantOrThrow(productId: string, variantId: string) {
    const variant = await this.repo.findVariant(productId, variantId);
    if (!variant) throw new NotFoundException('Variant not found');
    return variant;
  }

  private orderBy(sort?: ProductSort): Prisma.ProductOrderByWithRelationInput[] {
    switch (sort) {
      case 'oldest':
        return [{ createdAt: 'asc' }];
      case 'price_asc':
        return [{ price: 'asc' }];
      case 'price_desc':
        return [{ price: 'desc' }];
      case 'best_selling':
        return [{ ordersCount: 'desc' }];
      case 'top_rated':
        return [{ rating: 'desc' }, { reviewsCount: 'desc' }];
      case 'newest':
      default:
        return [{ createdAt: 'desc' }];
    }
  }
}
