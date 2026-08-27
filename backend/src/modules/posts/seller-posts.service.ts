import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { assertCanManage } from '../../common/authz';
import { AppEvent } from '../../common/events/app-events';
import { serializePost } from '../../common/serializers';
import { PostsRepository } from './posts.repository';
import { CreatePostDto } from './dto/create-post.dto';
import { UpdatePostDto } from './dto/update-post.dto';

/** Seller-only authoring of social posts. */
@Injectable()
export class SellerPostsService {
  constructor(
    private readonly repo: PostsRepository,
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
  ) {}

  async create(user: AuthUser, dto: CreatePostDto) {
    const product = await this.prisma.product.findUnique({
      where: { id: dto.product_id },
      select: { id: true, offers: { select: { sellerId: true } } },
    });
    if (!product) throw new NotFoundException('Product not found');

    // A seller may only feature their own products.
    const managerRoles: UserRole[] = [
      UserRole.SUPER_ADMIN,
      UserRole.OPERATIONS_ADMIN,
      UserRole.CONTENT_MODERATOR,
      UserRole.ADMIN,
    ];
    // A seller may post about any product they actually list.
    const listsProduct = product.offers.some(
      (offer) => offer.sellerId === user.id,
    );
    if (!managerRoles.includes(user.role) && !listsProduct) {
      throw new ForbiddenException('You can only post about products you sell');
    }

    const post = await this.repo.create(
      {
        author: { connect: { id: user.id } },
        product: { connect: { id: dto.product_id } },
        caption: dto.caption,
      },
      user.id,
    );
    this.events.emit(AppEvent.PostPublished, {
      sellerId: user.id,
      postId: post.id,
    });
    return serializePost(post, user.id);
  }

  async update(user: AuthUser, id: string, dto: UpdatePostDto) {
    const owner = await this.ownedOrThrow(user, id);
    const post = await this.repo.update(id, { caption: dto.caption }, owner.authorId);
    return serializePost(post, user.id);
  }

  async remove(user: AuthUser, id: string) {
    await this.ownedOrThrow(user, id);
    await this.repo.delete(id);
    return { message: 'Post deleted' };
  }

  private async ownedOrThrow(user: AuthUser, id: string) {
    const owner = await this.repo.findOwner(id);
    if (!owner) throw new NotFoundException('Post not found');
    assertCanManage(owner.authorId, user);
    return owner;
  }
}
