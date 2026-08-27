import {
  CommerceContentAnalyticsEventType,
  CommerceContentModerationStatus,
  CommerceContentPublicationChannel,
  CommerceContentStatus,
  CommerceContentVisibility,
  Prisma,
} from '@prisma/client';
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  PRODUCT_CARD_INCLUDE,
  PURCHASABLE_PRODUCT_WHERE,
} from '../../common/catalog/product-include';

export const commerceContentInclude = {
  seller: true,
  typeDefinition: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
  productTags: {
    orderBy: { sortOrder: 'asc' as const },
    include: {
      product: { include: PRODUCT_CARD_INCLUDE },
      variant: true,
    },
  },
  versions: {
    orderBy: { version: 'desc' as const },
    take: 20,
  },
} satisfies Prisma.CommerceContentInclude;

@Injectable()
export class CommerceContentRepository {
  constructor(private readonly prisma: PrismaService) {}

  listContentTypes(includeInactive = false) {
    return this.prisma.commerceContentTypeDefinition.findMany({
      where: includeInactive ? {} : { active: true },
      orderBy: [{ active: 'desc' }, { name: 'asc' }],
    });
  }

  findContentType(key: string) {
    return this.prisma.commerceContentTypeDefinition.findUnique({
      where: { key },
    });
  }

  upsertContentType(data: Prisma.CommerceContentTypeDefinitionCreateInput) {
    return this.prisma.commerceContentTypeDefinition.upsert({
      where: { key: data.key },
      create: data,
      update: {
        name: data.name,
        description: data.description,
        schema: data.schema,
        uiSchema: data.uiSchema,
        capabilities: data.capabilities,
        lifecycle: data.lifecycle,
        active: data.active,
        version: data.version,
      },
    });
  }

  createContent(data: Prisma.CommerceContentCreateInput) {
    return this.prisma.commerceContent.create({
      data,
      include: commerceContentInclude,
    });
  }

  updateContent(id: string, data: Prisma.CommerceContentUpdateInput) {
    return this.prisma.commerceContent.update({
      where: { id },
      data,
      include: commerceContentInclude,
    });
  }

  findById(id: string) {
    return this.prisma.commerceContent.findUnique({
      where: { id },
      include: commerceContentInclude,
    });
  }

  findPublished(id: string) {
    return this.prisma.commerceContent.findFirst({
      where: {
        id,
        status: CommerceContentStatus.PUBLISHED,
        visibility: { in: [CommerceContentVisibility.PUBLIC, CommerceContentVisibility.UNLISTED] },
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
      include: commerceContentInclude,
    });
  }

  findOwner(id: string) {
    return this.prisma.commerceContent.findUnique({
      where: { id },
      select: {
        id: true,
        sellerId: true,
        status: true,
        moderationStatus: true,
        scheduledAt: true,
        expiresAt: true,
        contentType: true,
        publicationTargets: true,
      },
    });
  }

  productsForTags(productIds: string[]) {
    return this.prisma.product.findMany({
      where: { id: { in: productIds } },
      select: { id: true, offers: { select: { sellerId: true } } },
    });
  }

  variantsForTags(variantIds: string[]) {
    return this.prisma.productVariant.findMany({
      where: { id: { in: variantIds } },
      select: { id: true, productId: true },
    });
  }

  listSeller(input: {
    sellerId: string;
    skip: number;
    take: number;
    status?: CommerceContentStatus;
    contentType?: string;
    q?: string;
  }) {
    const where = this.sellerWhere(input);
    return this.prisma.commerceContent.findMany({
      where,
      orderBy: [{ updatedAt: 'desc' }, { createdAt: 'desc' }],
      skip: input.skip,
      take: input.take,
      include: commerceContentInclude,
    });
  }

  countSeller(input: {
    sellerId: string;
    status?: CommerceContentStatus;
    contentType?: string;
    q?: string;
  }) {
    return this.prisma.commerceContent.count({ where: this.sellerWhere(input) });
  }

  feed(input: {
    skip: number;
    take: number;
    channel?: CommerceContentPublicationChannel;
    contentType?: string;
    sellerId?: string;
  }) {
    const where = this.feedWhere(input);
    return this.prisma.commerceContent.findMany({
      where,
      orderBy: [
        { pinnedUntil: 'desc' },
        { publishedAt: 'desc' },
        { engagementCount: 'desc' },
      ],
      skip: input.skip,
      take: input.take,
      include: commerceContentInclude,
    });
  }

  countFeed(input: {
    channel?: CommerceContentPublicationChannel;
    contentType?: string;
    sellerId?: string;
  }) {
    return this.prisma.commerceContent.count({ where: this.feedWhere(input) });
  }

  latestVersion(contentId: string) {
    return this.prisma.commerceContentVersion.aggregate({
      where: { contentId },
      _max: { version: true },
    });
  }

  findVersion(contentId: string, version: number) {
    return this.prisma.commerceContentVersion.findUnique({
      where: { contentId_version: { contentId, version } },
    });
  }

  createVersion(data: Prisma.CommerceContentVersionCreateInput) {
    return this.prisma.commerceContentVersion.create({ data });
  }

  createModerationAction(data: Prisma.CommerceContentModerationActionCreateInput) {
    return this.prisma.commerceContentModerationAction.create({ data });
  }

  publishDue(_limit: number) {
    const now = new Date();
    return this.prisma.commerceContent.updateMany({
      where: {
        status: CommerceContentStatus.SCHEDULED,
        moderationStatus: CommerceContentModerationStatus.APPROVED,
        scheduledAt: { lte: now },
      },
      data: { status: CommerceContentStatus.PUBLISHED, publishedAt: now },
    });
  }

  expireDue(_limit: number) {
    return this.prisma.commerceContent.updateMany({
      where: {
        status: CommerceContentStatus.PUBLISHED,
        expiresAt: { lte: new Date() },
      },
      data: { status: CommerceContentStatus.EXPIRED },
    });
  }

  findViewer(contentId: string, userId: string) {
    return this.prisma.commerceContentViewer.findUnique({
      where: { contentId_userId: { contentId, userId } },
    });
  }

  recordEvent(input: {
    contentId: string;
    actorId?: string;
    type: CommerceContentAnalyticsEventType;
    productId?: string;
    value?: number;
    watchTimeMs?: number;
    metadata?: Prisma.InputJsonValue;
    contentUpdate: Prisma.CommerceContentUpdateInput;
    viewerUpdate?: 'create' | 'update';
  }) {
    const operations: Prisma.PrismaPromise<unknown>[] = [
      this.prisma.commerceContentEvent.create({
        data: {
          contentId: input.contentId,
          actorId: input.actorId,
          type: input.type,
          productId: input.productId,
          value: input.value,
          watchTimeMs: input.watchTimeMs,
          metadata: input.metadata,
        },
      }),
      this.prisma.commerceContent.update({
        where: { id: input.contentId },
        data: input.contentUpdate,
      }),
    ];

    if (input.viewerUpdate && input.actorId) {
      operations.push(
        input.viewerUpdate === 'create'
          ? this.prisma.commerceContentViewer.create({
              data: { contentId: input.contentId, userId: input.actorId },
            })
          : this.prisma.commerceContentViewer.update({
              where: {
                contentId_userId: {
                  contentId: input.contentId,
                  userId: input.actorId,
                },
              },
              data: {
                viewsCount: { increment: 1 },
                lastViewedAt: new Date(),
              },
            }),
      );
    }

    return this.prisma.$transaction(operations);
  }

  private sellerWhere(input: {
    sellerId: string;
    status?: CommerceContentStatus;
    contentType?: string;
    q?: string;
  }): Prisma.CommerceContentWhereInput {
    return {
      sellerId: input.sellerId,
      ...(input.status ? { status: input.status } : {}),
      ...(input.contentType ? { contentType: input.contentType } : {}),
      ...(input.q
        ? {
            OR: [
              { title: { contains: input.q, mode: 'insensitive' } },
              { body: { contains: input.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
  }

  private feedWhere(input: {
    channel?: CommerceContentPublicationChannel;
    contentType?: string;
    sellerId?: string;
  }): Prisma.CommerceContentWhereInput {
    return {
      status: CommerceContentStatus.PUBLISHED,
      visibility: CommerceContentVisibility.PUBLIC,
      OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      ...(input.channel ? { publicationTargets: { has: input.channel } } : {}),
      ...(input.contentType ? { contentType: input.contentType } : {}),
      ...(input.sellerId ? { sellerId: input.sellerId } : {}),
    };
  }
}
