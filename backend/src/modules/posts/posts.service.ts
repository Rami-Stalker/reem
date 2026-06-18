import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import { serializeComment, serializePost } from '../../common/serializers';
import { PostsRepository } from './posts.repository';

/** Customer + shared post operations (feed, engagement, comments). */
@Injectable()
export class PostsService {
  constructor(
    private readonly repo: PostsRepository,
    private readonly prisma: PrismaService,
  ) {}

  async feed(userId: string, page: PaginationDto) {
    const [posts, total] = await Promise.all([
      this.repo.feed(userId, page.skip, page.limit),
      this.repo.countAll(),
    ]);
    return {
      data: posts.map((p) => serializePost(p, userId)),
      pagination: buildMeta(page.page, page.limit, total, posts.length),
    };
  }

  async bySeller(sellerId: string, userId: string, page: PaginationDto) {
    const [posts, total] = await Promise.all([
      this.repo.bySeller(sellerId, userId, page.skip, page.limit),
      this.repo.countBySeller(sellerId),
    ]);
    return {
      data: posts.map((p) => serializePost(p, userId)),
      pagination: buildMeta(page.page, page.limit, total, posts.length),
    };
  }

  async saved(userId: string, page: PaginationDto) {
    const [posts, total] = await Promise.all([
      this.repo.saved(userId, page.skip, page.limit),
      this.repo.countSaved(userId),
    ]);
    return {
      data: posts.map((p) => serializePost(p, userId)),
      pagination: buildMeta(page.page, page.limit, total, posts.length),
    };
  }

  async single(id: string, userId: string) {
    const post = await this.repo.findById(id, userId);
    if (!post) throw new NotFoundException('Post not found');
    return serializePost(post, userId);
  }

  async toggleLike(userId: string, postId: string) {
    await this.ensureExists(postId);
    const existing = await this.prisma.postLike.findUnique({
      where: { postId_userId: { postId, userId } },
    });
    if (existing) {
      await this.prisma.$transaction([
        this.prisma.postLike.delete({ where: { id: existing.id } }),
        this.prisma.post.update({
          where: { id: postId },
          data: { likesCount: { decrement: 1 } },
        }),
      ]);
    } else {
      await this.prisma.$transaction([
        this.prisma.postLike.create({ data: { postId, userId } }),
        this.prisma.post.update({
          where: { id: postId },
          data: { likesCount: { increment: 1 } },
        }),
      ]);
    }
    return this.single(postId, userId);
  }

  async toggleSave(userId: string, postId: string) {
    await this.ensureExists(postId);
    const existing = await this.prisma.postSave.findUnique({
      where: { postId_userId: { postId, userId } },
    });
    if (existing) {
      await this.prisma.$transaction([
        this.prisma.postSave.delete({ where: { id: existing.id } }),
        this.prisma.post.update({
          where: { id: postId },
          data: { savesCount: { decrement: 1 } },
        }),
      ]);
    } else {
      await this.prisma.$transaction([
        this.prisma.postSave.create({ data: { postId, userId } }),
        this.prisma.post.update({
          where: { id: postId },
          data: { savesCount: { increment: 1 } },
        }),
      ]);
    }
    return this.single(postId, userId);
  }

  async share(userId: string, postId: string) {
    await this.ensureExists(postId);
    await this.prisma.post.update({
      where: { id: postId },
      data: { sharesCount: { increment: 1 } },
    });
    return this.single(postId, userId);
  }

  async listComments(postId: string, page: PaginationDto) {
    await this.ensureExists(postId);
    const [comments, total] = await Promise.all([
      this.prisma.comment.findMany({
        where: { postId },
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
        include: { user: true },
      }),
      this.prisma.comment.count({ where: { postId } }),
    ]);
    return {
      data: comments.map(serializeComment),
      pagination: buildMeta(page.page, page.limit, total, comments.length),
    };
  }

  async addComment(userId: string, postId: string, content: string) {
    await this.ensureExists(postId);
    const [comment] = await this.prisma.$transaction([
      this.prisma.comment.create({
        data: { postId, userId, content },
        include: { user: true },
      }),
      this.prisma.post.update({
        where: { id: postId },
        data: { commentsCount: { increment: 1 } },
      }),
    ]);
    return serializeComment(comment);
  }

  async deleteComment(user: AuthUser, postId: string, commentId: string) {
    const comment = await this.prisma.comment.findFirst({
      where: { id: commentId, postId },
    });
    if (!comment) throw new NotFoundException('Comment not found');

    const post = await this.repo.findOwner(postId);
    const allowed =
      user.role === UserRole.ADMIN ||
      comment.userId === user.id ||
      post?.authorId === user.id;
    if (!allowed) {
      throw new ForbiddenException('You cannot delete this comment');
    }

    await this.prisma.$transaction([
      this.prisma.comment.delete({ where: { id: commentId } }),
      this.prisma.post.update({
        where: { id: postId },
        data: { commentsCount: { decrement: 1 } },
      }),
    ]);
    return { message: 'Comment deleted' };
  }

  private async ensureExists(postId: string) {
    const post = await this.repo.findOwner(postId);
    if (!post) throw new NotFoundException('Post not found');
    return post;
  }
}
