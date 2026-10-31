import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { User, UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  serializePublicUser,
  serializeUser,
  serializeUserProfile,
} from '../../common/serializers';
import { UsersRepository } from './users.repository';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { MediaService } from '../media/media.service';
import { AppEvent } from '../../common/events/app-events';

@Injectable()
export class UsersService {
  constructor(
    private readonly users: UsersRepository,
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly events: EventEmitter2,
  ) {}

  /** The signed-in user's own profile (with stats). */
  async getMe(userId: string) {
    const user = await this.requireUser(userId);
    return serializeUserProfile(user, await this.profileExtras(user, userId, true));
  }

  async updateMe(userId: string, dto: UpdateProfileDto) {
    const email = this.normaliseEmail(dto.email);
    if (email) await this.assertEmailFree(email, userId);

    const user = await this.users.update(userId, {
      ...(dto.name !== undefined && { name: dto.name.trim() }),
      ...(dto.bio !== undefined && { bio: dto.bio }),
      ...(dto.image_url !== undefined && { imageUrl: dto.image_url }),
      ...(dto.location !== undefined && { location: dto.location }),
      ...(dto.email !== undefined && {
        email,
        // A changed address is unverified until it answers. Clearing it clears
        // the proof with it, so a stale verification cannot be inherited by a
        // new address.
        emailVerifiedAt: null,
      }),
    });
    if (dto.image_url) await this.media.markAttached(userId, [dto.image_url]);
    return serializeUser(user);
  }

  /** Lower-cased and trimmed; an empty string means "remove it". */
  private normaliseEmail(email?: string | null): string | null | undefined {
    if (email === undefined) return undefined;
    const trimmed = (email ?? '').trim().toLowerCase();
    return trimmed.length === 0 ? null : trimmed;
  }

  /**
   * `users.email` is unique, so a duplicate would surface as a Prisma P2002 —
   * a 500 with a stack trace where the honest answer is "somebody already
   * uses that address".
   */
  private async assertEmailFree(email: string, userId: string): Promise<void> {
    const owner = await this.prisma.user.findUnique({
      where: { email },
      select: { id: true },
    });
    if (owner && owner.id !== userId) {
      throw new ConflictException('هذا البريد مستخدم بحساب آخر');
    }
  }

  /** Any user's public profile, annotated with the viewer's relationship. */
  async getProfile(targetId: string, viewerId?: string) {
    const user = await this.requireUser(targetId);
    const isMe = viewerId !== undefined && targetId === viewerId;
    return serializeUserProfile(
      user,
      await this.profileExtras(user, viewerId, isMe),
    );
  }

  async follow(followerId: string, targetId: string) {
    if (followerId === targetId) {
      throw new BadRequestException('You cannot follow yourself');
    }
    const target = await this.requireUser(targetId);

    // A shopper's page is hers until she opens it.
    //
    // Q17 said customers may follow boutiques only, and nothing in the code
    // ever enforced it — the rule lived in a comment in the demo seed, so any
    // caller could already follow any account. The rule now is the owner's:
    // she opts in, and until she does she cannot be followed. A boutique is
    // always followable; a storefront nobody may follow is not a storefront.
    if (target.role === UserRole.CUSTOMER && !target.profileIsPublic) {
      throw new ForbiddenException('PROFILE_IS_PRIVATE');
    }

    const existing = await this.users.findFollow(followerId, targetId);
    if (!existing) {
      // Create the edge and bump both denormalised counters atomically.
      await this.prisma.$transaction([
        this.prisma.follow.create({
          data: { followerId, followingId: targetId },
        }),
        this.prisma.user.update({
          where: { id: targetId },
          data: { followersCount: { increment: 1 } },
        }),
        this.prisma.user.update({
          where: { id: followerId },
          data: { followingCount: { increment: 1 } },
        }),
      ]);
    }

    const updated = await this.requireUser(targetId);
    this.events.emit(AppEvent.UserFollowed, {
      userId: targetId,
      followerId,
    });
    return {
      message: 'Now following',
      is_following: true,
      followers_count: updated.followersCount,
    };
  }

  /**
   * Opening or closing her page.
   *
   * One transaction across three tables. `commerce_contents.author_is_public`
   * and `commerce_content_reshares.resharer_is_public` are denormalised copies
   * of this flag, and they are the one denormalisation here whose staleness
   * would be a *privacy* bug rather than a stale number — a row left `true`
   * publishes a woman's page to strangers. They fail closed and they move with
   * her, in the same transaction, so there is no window where the two disagree.
   *
   * Going private does **not** drop her existing followers. She let them in;
   * taking that back is a separate act, and silently severing every connection
   * she has made is not what "make my page private" means to anybody.
   */
  async setProfileVisibility(userId: string, isPublic: boolean) {
    const now = new Date();
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: {
          profileIsPublic: isPublic,
          profilePublicSince: isPublic ? now : null,
        },
      }),
      this.prisma.commerceContent.updateMany({
        where: { authorId: userId },
        data: { authorIsPublic: isPublic },
      }),
      this.prisma.commerceContentReshare.updateMany({
        where: { resharerId: userId },
        data: { resharerIsPublic: isPublic },
      }),
    ]);

    return {
      is_public: isPublic,
      // What changes, said plainly, because "public profile" means different
      // things on different platforms and she is entitled to know which.
      followers_kept: true,
    };
  }

  async unfollow(followerId: string, targetId: string) {
    if (followerId === targetId) {
      throw new BadRequestException('You cannot unfollow yourself');
    }
    await this.requireUser(targetId);

    const existing = await this.users.findFollow(followerId, targetId);
    if (existing) {
      await this.prisma.$transaction([
        this.prisma.follow.delete({ where: { id: existing.id } }),
        this.prisma.user.update({
          where: { id: targetId },
          data: { followersCount: { decrement: 1 } },
        }),
        this.prisma.user.update({
          where: { id: followerId },
          data: { followingCount: { decrement: 1 } },
        }),
      ]);
    }

    const target = await this.requireUser(targetId);
    return {
      message: 'Unfollowed',
      is_following: false,
      followers_count: target.followersCount,
    };
  }

  async listFollowers(targetId: string) {
    await this.requireUser(targetId);
    const followers = await this.users.listFollowers(targetId);
    // Public: anyone can open these lists. `serializeUser` carried each
    // person's phone number and email to whoever looked.
    return followers.map((user) => serializePublicUser(user));
  }

  async listFollowing(targetId: string) {
    await this.requireUser(targetId);
    const following = await this.users.listFollowing(targetId);
    return following.map((user) => serializePublicUser(user));
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  private async requireUser(id: string): Promise<User> {
    const user = await this.users.findById(id);
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  private async profileExtras(user: User, viewerId: string | undefined, isMe: boolean) {
    const isSeller = user.role === UserRole.SELLER;
    const [postsCount, isFollowing, sellerStats, picksCount, hasStory, adTier] =
      await Promise.all([
        this.users.countPosts(user.id),
        // A visitor follows nobody. Asked with no follower, the lookup
        // by compound key throws rather than answering no.
        isMe || !viewerId
          ? Promise.resolve(false)
          : this.users.findFollow(viewerId, user.id).then(Boolean),
        isSeller ? this.users.sellerStats(user.id) : Promise.resolve(null),
        this.users.countVisiblePicks(user, viewerId),
        this.users.hasVisibleStory(user, viewerId),
        isSeller ? this.adTierOf(user.id) : Promise.resolve(null),
      ]);

    return {
      isMe,
      isFollowing,
      postsCount,
      picksCount,
      hasStory,
      productsCount: sellerStats?.productsCount ?? 0,
      sellerStats,
      adTier,
    };
  }

  /**
   * The advertising plan a boutique carries right now — «فضي/ذهبي/ماسي» on
   * her page. Null for free, which wears no badge.
   */
  private async adTierOf(sellerId: string): Promise<string | null> {
    const now = new Date();
    const rows = await this.prisma.storeAdSubscription.findMany({
      where: { sellerId, startsAt: { lte: now }, endsAt: { gt: now } },
      select: { tier: true },
    });
    const order = ['FREE', 'SILVER', 'GOLD', 'DIAMOND'];
    const best = rows
      .map((row) => row.tier as string)
      .sort((a, b) => order.indexOf(b) - order.indexOf(a))[0];
    return best && best !== 'FREE' ? best.toLowerCase() : null;
  }
}
