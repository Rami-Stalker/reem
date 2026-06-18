import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

const productInclude = {
  seller: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
  variants: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.ProductInclude;

@Injectable()
export class PostsRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Post include scoped to a viewer so `is_liked`/`is_saved` resolve. */
  private include(userId: string) {
    return {
      author: true,
      product: { include: productInclude },
      likes: { where: { userId } },
      saves: { where: { userId } },
    } satisfies Prisma.PostInclude;
  }

  feed(userId: string, skip: number, take: number) {
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

  bySeller(sellerId: string, userId: string, skip: number, take: number) {
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

  findById(id: string, userId: string) {
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
