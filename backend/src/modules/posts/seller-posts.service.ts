import { Injectable, NotFoundException } from '@nestjs/common';
import {
  CommerceAuthorKind,
  CommerceContentStatus,
  ContentTagBasis,
} from '@prisma/client';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../../prisma/prisma.service';
import { PRODUCT_CARD_INCLUDE } from '../../common/catalog/product-include';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { assertCanManage } from '../../common/authz';
import { AppEvent } from '../../common/events/app-events';
import { serializeLegacyPost } from '../../common/serializers';
import { ContentAttributionService } from '../commerce-content/attribution/content-attribution.service';
import { ProductTagPolicyService } from '../commerce-content/tagging/product-tag-policy.service';
import { assertAuthorMayChange } from '../commerce-content/commerce-content.service';
import { screenText } from '../commerce-content/content-policy';
import { ContentModerationService } from '../commerce-content/moderation/content-moderation.service';
import { CreatePostDto } from './dto/create-post.dto';
import { UpdatePostDto } from './dto/update-post.dto';

/**
 * `POST|PATCH|DELETE /seller/posts` — writing to the content platform.
 *
 * Kept because the shipped app's composer calls it. What it creates is a
 * `product_post` `CommerceContent`, indistinguishable from one made through
 * `/content` except that this route takes exactly one product, which is all
 * the old client can express.
 *
 * The entitlement check moved to `ProductTagPolicyService`. The one that lived
 * here had the same defect as the platform's: it read `product.offers` with no
 * status filter, so a boutique could feature a product whose listing she had
 * archived.
 */
@Injectable()
export class SellerPostsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
    private readonly tagPolicy: ProductTagPolicyService,
    private readonly attribution: ContentAttributionService,
    private readonly moderation: ContentModerationService,
  ) {}

  private readonly include = {
    author: true,
    media: { orderBy: { sortOrder: 'asc' as const } },
    productTags: {
      orderBy: { sortOrder: 'asc' as const },
      include: { product: { include: PRODUCT_CARD_INCLUDE }, variant: true },
    },
  };

  async create(user: AuthUser, dto: CreatePostDto) {
    const product = await this.prisma.product.findUnique({
      where: { id: dto.product_id },
      select: { id: true },
    });
    if (!product) throw new NotFoundException('Product not found');

    const verdicts = await this.tagPolicy.assert(user, [dto.product_id]);
    const verdict = verdicts.get(dto.product_id);
    const author = await this.prisma.user.findUnique({
      where: { id: user.id },
      select: { role: true, profileIsPublic: true },
    });

    const post = await this.prisma.commerceContent.create({
      data: {
        authorId: user.id,
        authorKind:
          author?.role === 'CUSTOMER'
            ? CommerceAuthorKind.CUSTOMER
            : CommerceAuthorKind.SELLER,
        authorIsPublic: author?.profileIsPublic ?? true,
        contentType: 'product_post',
        body: dto.caption,
        locale: 'ar',
        // This route has no draft step — the old composer publishes on submit,
        // and giving it one would leave every post from the shipped app
        // invisible in a workspace its client cannot open.
        status: CommerceContentStatus.PUBLISHED,
        moderationStatus: 'APPROVED',
        publishedAt: new Date(),
        payload: { caption: dto.caption, legacy: 'post' },
        publicationTargets: ['HOME_FEED', 'STORE_FEED', 'FOLLOWING_FEED'],
        productTags: {
          create: [
            {
              productId: dto.product_id,
              role: 'featured',
              sortOrder: 0,
              basis: verdict?.basis ?? ContentTagBasis.SELLER_OFFER,
              ...(verdict?.sourceOrderItemId
                ? { sourceOrderItemId: verdict.sourceOrderItemId }
                : {}),
            },
          ],
        },
      },
      include: this.include,
    });

    await this.attribution.rebuild(post.id);
    // Live already; a caption that trips the screen is shown to a moderator.
    await this.moderation.autoFlag(post.id, screenText(dto.caption));
    this.events.emit(AppEvent.PostPublished, {
      sellerId: user.id,
      postId: post.id,
    });
    return serializeLegacyPost(post);
  }

  async update(user: AuthUser, id: string, dto: UpdatePostDto) {
    const owner = await this.ownedOrThrow(user, id);
    assertAuthorMayChange(owner.status);
    const post = await this.prisma.commerceContent.update({
      where: { id },
      data: {
        body: dto.caption,
        payload: { caption: dto.caption, legacy: 'post' },
      },
      include: this.include,
    });
    // The same screen the content platform runs on an edit: the post stays
    // up, and a caption edited into an off-platform phone number is put in
    // front of a moderator, who can take it down from the console.
    await this.moderation.autoFlag(id, screenText(dto.caption));
    return serializeLegacyPost(post);
  }

  /**
   * Her own deletion, which is `DELETED` and never `REMOVED`.
   *
   * The old implementation was a hard `prisma.post.delete`, so a post and
   * every like and comment on it vanished with no record that it had existed.
   * A soft delete keeps the trail an appeal or an incident review needs, and
   * keeps the two words meaning different things: she changed her mind, or we
   * intervened.
   */
  async remove(user: AuthUser, id: string) {
    const owner = await this.ownedOrThrow(user, id);
    if (owner.status === CommerceContentStatus.DELETED) {
      return { message: 'Post deleted' };
    }
    assertAuthorMayChange(owner.status);
    await this.prisma.commerceContent.update({
      where: { id },
      data: {
        status: CommerceContentStatus.DELETED,
        archivedAt: new Date(),
      },
    });
    return { message: 'Post deleted' };
  }

  private async ownedOrThrow(user: AuthUser, id: string) {
    const owner = await this.prisma.commerceContent.findFirst({
      where: { id, contentType: 'product_post' },
      select: { id: true, authorId: true, status: true },
    });
    if (!owner) throw new NotFoundException('Post not found');
    assertCanManage(owner.authorId, user);
    return owner;
  }
}
