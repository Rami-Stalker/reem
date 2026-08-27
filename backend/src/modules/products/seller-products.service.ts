import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  MediaType,
  ModerationStatus,
  Prisma,
  ProductStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import {
  OFFER_INCLUDE,
  PRODUCT_INCLUDE,
} from '../../common/catalog/product-include';
import { serializeOffer, serializeProduct, serializeVariant } from '../../common/serializers';
import { ProductsRepository } from './products.repository';
import { CatalogRollupService } from './catalog-rollup.service';
import { MediaService } from '../media/media.service';
import { SellerOffersService } from './seller-offers.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { CreateVariantDto, UpdateVariantDto } from './dto/product-variant.dto';

const ADMIN_ROLES: readonly UserRole[] = [
  UserRole.SUPER_ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.CONTENT_MODERATOR,
  UserRole.ADMIN,
];

/**
 * Authoring the CANONICAL catalog entry.
 *
 * A seller may propose a product that does not exist yet, and edit it while
 * they remain the only one selling it. The moment a second seller lists the
 * same product the entry becomes shared and only moderators may change it —
 * otherwise one seller could rewrite the page a competitor sells from.
 */
@Injectable()
export class SellerProductsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly repo: ProductsRepository,
    private readonly rollup: CatalogRollupService,
    private readonly offers: SellerOffersService,
    private readonly media: MediaService,
  ) {}

  async create(user: AuthUser, dto: CreateProductDto) {
    await this.assertLeafCategory(dto.category_id, dto.attributes);

    const slug = await this.uniqueSlug(dto.title);
    const blurHashes = await this.blurHashesFor(user, dto.media);

    const product = await this.prisma.$transaction(async (tx) => {
      const created = await tx.product.create({
        data: {
          slug,
          title: dto.title.trim(),
          description: dto.description,
          category: { connect: { id: dto.category_id } },
          ...(dto.brand_id ? { brand: { connect: { id: dto.brand_id } } } : {}),
          attributes: (dto.attributes as Prisma.InputJsonValue) ?? Prisma.JsonNull,
          gtin: dto.gtin?.trim() || null,
          createdBySeller: { connect: { id: user.id } },
          // Q39 P1 — new sellers' products are reviewed before they go public.
          status: ProductStatus.DRAFT,
          moderationStatus: ModerationStatus.OPEN,
          media: dto.media?.length
            ? {
                create: dto.media.map((media, index) => ({
                  url: media.url,
                  type: media.type ?? MediaType.image,
                  sortOrder: media.sort_order ?? index,
                  blurHash: blurHashes.get(media.url) ?? null,
                })),
              }
            : undefined,
          variants: dto.variants?.length
            ? {
                create: dto.variants.map((variant, index) => ({
                  name: variant.name,
                  attributes: variant.attributes as Prisma.InputJsonValue,
                  imageUrl: variant.image_url ?? null,
                  sortOrder: variant.sort_order ?? index,
                })),
              }
            : undefined,
        },
        include: PRODUCT_INCLUDE,
      });
      return created;
    });

    // The seller's own listing on the entry they just proposed.
    const offer = await this.offers.create(user, {
      ...dto.offer,
      product_id: product.id,
    });

    await this.claimUploads(user.id, dto);

    const withOffer = await this.repo.findById(product.id);
    return {
      ...serializeProduct(withOffer!, { includeOffers: true }),
      my_offer: offer,
    };
  }

  async update(user: AuthUser, id: string, dto: UpdateProductDto) {
    await this.assertMayEditCanonical(user, id);
    if (dto.category_id) {
      await this.assertLeafCategory(dto.category_id, dto.attributes);
    }

    const blurHashes = await this.blurHashesFor(user, dto.media);

    const data: Prisma.ProductUpdateInput = {
      ...(dto.title !== undefined && { title: dto.title.trim() }),
      ...(dto.description !== undefined && { description: dto.description }),
      ...(dto.category_id !== undefined && {
        category: { connect: { id: dto.category_id } },
      }),
      ...(dto.brand_id !== undefined && {
        brand: { connect: { id: dto.brand_id } },
      }),
      ...(dto.attributes !== undefined && {
        attributes: dto.attributes as Prisma.InputJsonValue,
      }),
      ...(dto.gtin !== undefined && { gtin: dto.gtin?.trim() || null }),
      // Replace the gallery wholesale when provided.
      ...(dto.media !== undefined && {
        media: {
          deleteMany: {},
          create: dto.media.map((media, index) => ({
            url: media.url,
            type: media.type ?? MediaType.image,
            sortOrder: media.sort_order ?? index,
            blurHash: blurHashes.get(media.url) ?? null,
          })),
        },
      }),
      // Any content edit re-enters the moderation queue (Q103 P2).
      moderationStatus: ModerationStatus.OPEN,
    };

    const product = await this.repo.update(id, data);
    await this.claimUploads(user.id, dto);
    return serializeProduct(product, { includeOffers: true });
  }

  /**
   * Keep the uploads this product now points at.
   *
   * Note what is deliberately absent: nothing *un*-claims the gallery images an
   * edit replaced. Those rows stay ATTACHED and their bytes stay on disk, which
   * costs a little storage and buys the one thing that matters more — an edit
   * that goes wrong, or a seller who changes her mind, never destroys a
   * photograph she may still be using somewhere else.
   */
  /**
   * The blur hash for each photograph she is attaching, resolved before the
   * row is written so the card can draw a placeholder without a join.
   */
  private async blurHashesFor(
    user: AuthUser,
    media: { url: string }[] | undefined,
  ): Promise<Map<string, string | null>> {
    if (!media?.length) return new Map();
    return this.media.blurHashesFor(
      media.map((entry) => entry.url),
      user.id,
    );
  }

  private async claimUploads(
    ownerId: string,
    dto: CreateProductDto | UpdateProductDto,
  ): Promise<void> {
    const urls = [
      ...(dto.media?.map((media) => media.url) ?? []),
      ...(('variants' in dto ? dto.variants : undefined)?.map(
        (variant) => variant.image_url,
      ) ?? []),
    ];
    if (urls.length) await this.media.markAttached(ownerId, urls);
  }

  async getMine(user: AuthUser, id: string) {
    const product = await this.prisma.product.findUnique({
      where: { id },
      include: {
        ...PRODUCT_INCLUDE,
        offers: { where: { sellerId: user.id }, include: OFFER_INCLUDE },
      },
    });
    if (!product) throw new NotFoundException('Product not found');
    if (product.offers.length === 0 && !this.isAdmin(user)) {
      throw new ForbiddenException('You do not list this product');
    }
    return serializeProduct(product, { includeOffers: true });
  }

  // ── Canonical variants ──────────────────────────────────────────────────

  async addVariant(user: AuthUser, productId: string, dto: CreateVariantDto) {
    await this.assertMayEditCanonical(user, productId);
    const variant = await this.repo.createVariant({
      product: { connect: { id: productId } },
      name: dto.name,
      attributes: dto.attributes as Prisma.InputJsonValue,
      imageUrl: dto.image_url ?? null,
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
    await this.assertMayEditCanonical(user, productId);
    await this.variantOrThrow(productId, variantId);

    const variant = await this.repo.updateVariant(variantId, {
      ...(dto.name !== undefined && { name: dto.name }),
      ...(dto.attributes !== undefined && {
        attributes: dto.attributes as Prisma.InputJsonValue,
      }),
      ...(dto.image_url !== undefined && { imageUrl: dto.image_url }),
      ...(dto.sort_order !== undefined && { sortOrder: dto.sort_order }),
    });
    return serializeVariant(variant);
  }

  async removeVariant(user: AuthUser, productId: string, variantId: string) {
    await this.assertMayEditCanonical(user, productId);
    await this.variantOrThrow(productId, variantId);
    await this.repo.deleteVariant(variantId);
    await this.rollup.refreshAndSync(productId);
    return { message: 'Variant deleted' };
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  private isAdmin(user: AuthUser): boolean {
    return ADMIN_ROLES.includes(user.role);
  }

  /**
   * A seller may edit the shared catalog entry only while they are its sole
   * offerer. Admins always may.
   */
  private async assertMayEditCanonical(user: AuthUser, productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: {
        createdBySellerId: true,
        offers: { select: { sellerId: true } },
      },
    });
    if (!product) throw new NotFoundException('Product not found');
    if (this.isAdmin(user)) return product;

    const sellerIds = new Set(product.offers.map((offer) => offer.sellerId));
    const isSoleOfferer = sellerIds.size <= 1 && sellerIds.has(user.id);
    const isAuthor = product.createdBySellerId === user.id;

    if (!isAuthor || !isSoleOfferer) {
      throw new ForbiddenException(
        'Other sellers list this product — ask an administrator to edit the shared catalog entry',
      );
    }
    return product;
  }

  /**
   * Q26 P2 — products attach to LEAF categories only, so filters and attribute
   * schemas stay predictable. Q27 P2 — extra attributes are validated against
   * the schema the category (or its nearest ancestor) declares.
   */
  private async assertLeafCategory(
    categoryId: string,
    attributes: Record<string, unknown> | undefined,
  ) {
    const category = await this.prisma.category.findUnique({
      where: { id: categoryId },
      select: {
        id: true,
        level: true,
        isActive: true,
        attributeSchema: true,
        parentId: true,
        children: { select: { id: true }, take: 1 },
      },
    });
    if (!category) throw new NotFoundException('Category not found');
    if (!category.isActive) {
      throw new BadRequestException('That category is not accepting products');
    }
    if (category.children.length > 0) {
      throw new BadRequestException(
        'Products attach to leaf categories only — pick a sub-category',
      );
    }

    const schema = await this.resolveAttributeSchema(category);
    if (!schema) return;

    const required = Array.isArray((schema as { required?: unknown }).required)
      ? ((schema as { required: string[] }).required)
      : [];
    const missing = required.filter((key) => attributes?.[key] === undefined);
    if (missing.length > 0) {
      throw new BadRequestException(
        `This category requires: ${missing.join(', ')}`,
      );
    }
  }

  /** Walks up the tree to the nearest ancestor that declares a schema. */
  private async resolveAttributeSchema(category: {
    attributeSchema: Prisma.JsonValue;
    parentId: string | null;
  }): Promise<Prisma.JsonObject | null> {
    if (category.attributeSchema && typeof category.attributeSchema === 'object') {
      return category.attributeSchema as Prisma.JsonObject;
    }
    let parentId = category.parentId;
    while (parentId) {
      const parent: {
        attributeSchema: Prisma.JsonValue;
        parentId: string | null;
      } | null = await this.prisma.category.findUnique({
        where: { id: parentId },
        select: { attributeSchema: true, parentId: true },
      });
      if (!parent) return null;
      if (parent.attributeSchema && typeof parent.attributeSchema === 'object') {
        return parent.attributeSchema as Prisma.JsonObject;
      }
      parentId = parent.parentId;
    }
    return null;
  }

  private async uniqueSlug(title: string): Promise<string> {
    const base =
      title
        .toLowerCase()
        .trim()
        // Keep Arabic letters — a transliterated slug would be unreadable to
        // the sellers writing these titles.
        .replace(/[^\p{L}\p{N}]+/gu, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 80) || 'product';

    for (let attempt = 0; attempt < 25; attempt += 1) {
      const candidate = attempt === 0 ? base : `${base}-${attempt + 1}`;
      const taken = await this.prisma.product.findUnique({
        where: { slug: candidate },
        select: { id: true },
      });
      if (!taken) return candidate;
    }
    return `${base}-${Date.now().toString(36)}`;
  }

  private async variantOrThrow(productId: string, variantId: string) {
    const variant = await this.repo.findVariant(productId, variantId);
    if (!variant) throw new NotFoundException('Variant not found');
    return variant;
  }
}
