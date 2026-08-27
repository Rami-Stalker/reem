import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { User, UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  serializeUser,
  serializeUserProfile,
} from '../../common/serializers';
import { UsersRepository } from './users.repository';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { MediaService } from '../media/media.service';

@Injectable()
export class UsersService {
  constructor(
    private readonly users: UsersRepository,
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
  ) {}

  /** The signed-in user's own profile (with stats). */
  async getMe(userId: string) {
    const user = await this.requireUser(userId);
    return serializeUserProfile(user, await this.profileExtras(user, userId, true));
  }

  async updateMe(userId: string, dto: UpdateProfileDto) {
    const user = await this.users.update(userId, {
      ...(dto.name !== undefined && { name: dto.name.trim() }),
      ...(dto.bio !== undefined && { bio: dto.bio }),
      ...(dto.image_url !== undefined && { imageUrl: dto.image_url }),
      ...(dto.location !== undefined && { location: dto.location }),
    });
    if (dto.image_url) await this.media.markAttached(userId, [dto.image_url]);
    return serializeUser(user);
  }

  /** Any user's public profile, annotated with the viewer's relationship. */
  async getProfile(targetId: string, viewerId: string) {
    const user = await this.requireUser(targetId);
    const isMe = targetId === viewerId;
    return serializeUserProfile(
      user,
      await this.profileExtras(user, viewerId, isMe),
    );
  }

  async follow(followerId: string, targetId: string) {
    if (followerId === targetId) {
      throw new BadRequestException('You cannot follow yourself');
    }
    await this.requireUser(targetId);

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

    const target = await this.requireUser(targetId);
    return {
      message: 'Now following',
      is_following: true,
      followers_count: target.followersCount,
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
    return followers.map(serializeUser);
  }

  async listFollowing(targetId: string) {
    await this.requireUser(targetId);
    const following = await this.users.listFollowing(targetId);
    return following.map(serializeUser);
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  private async requireUser(id: string): Promise<User> {
    const user = await this.users.findById(id);
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  private async profileExtras(user: User, viewerId: string, isMe: boolean) {
    const isSeller = user.role === UserRole.SELLER;
    const [postsCount, isFollowing, sellerStats] = await Promise.all([
      this.users.countPosts(user.id),
      isMe
        ? Promise.resolve(false)
        : this.users.findFollow(viewerId, user.id).then(Boolean),
      isSeller ? this.users.sellerStats(user.id) : Promise.resolve(null),
    ]);

    return {
      isMe,
      isFollowing,
      postsCount,
      productsCount: sellerStats?.productsCount ?? 0,
      sellerStats,
    };
  }
}
