import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  PRODUCT_CARD_INCLUDE,
  PURCHASABLE_PRODUCT_WHERE,
} from '../../common/catalog/product-include';

@Injectable()
export class PostsRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Post include scoped to a viewer so `is_liked`/`is_saved` resolve.
   *
   * A signed-out visitor has no like or save state to resolve. The relations
   * are dropped with `take: 0` rather than left unfiltered, because
   * `where: { userId: undefined }` means "no filter" to Prisma — it would drag
   * every like row of every post in the page across the wire to compute a
   * flag that is false by definition.
   */
  private include(userId?: string) {
    const viewerScope = userId ? { where: { userId } } : { take: 0 };
    return {
      author: true,
      product: { include: PRODUCT_CARD_INCLUDE },
      likes: viewerScope,
      saves: viewerScope,
    } satisfies Prisma.PostInclude;
  }

  feed(userId: string | undefined, skip: number, take: number) {
    return this.prisma.post.findMany({
      orderBy: { createdAt: 'desc' },
      skip,
      take,
      include: this.include(userId),
    });
  }

  countAll() {
    return this.prisma.post.count();
  }

  bySeller(
    sellerId: string,
    userId: string | undefined,
    skip: number,
    take: number,
  ) {
    return this.prisma.post.findMany({
      where: { authorId: sellerId },
      orderBy: { createdAt: 'desc' },
      skip,
      take,
      include: this.include(userId),
    });
  }

  countBySeller(sellerId: string) {
    return this.prisma.post.count({ where: { authorId: sellerId } });
  }

  saved(userId: string, skip: number, take: number) {
    return this.prisma.post.findMany({
      where: { saves: { some: { userId } } },
      orderBy: { createdAt: 'desc' },
      skip,
      take,
      include: this.include(userId),
    });
  }

  countSaved(userId: string) {
    return this.prisma.post.count({ where: { saves: { some: { userId } } } });
  }

  findById(id: string, userId?: string) {
    return this.prisma.post.findUnique({
      where: { id },
      include: this.include(userId),
    });
  }

  findOwner(id: string) {
    return this.prisma.post.findUnique({
      where: { id },
      select: { id: true, authorId: true },
    });
  }

  create(data: Prisma.PostCreateInput, userId: string) {
    return this.prisma.post.create({ data, include: this.include(userId) });
  }

  update(id: string, data: Prisma.PostUpdateInput, userId: string) {
    return this.prisma.post.update({
      where: { id },
      data,
      include: this.include(userId),
    });
  }

  delete(id: string) {
    return this.prisma.post.delete({ where: { id } });
  }
}
