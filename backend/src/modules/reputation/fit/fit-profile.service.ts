import { BadRequestException, Injectable } from '@nestjs/common';
import { FitProfile } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import {
  HEIGHT_MAX_CM,
  HEIGHT_MIN_CM,
  Viewer,
  usualSizeOf,
} from './fit-reviews';

export interface FitProfilePatch {
  /** `null` clears it; `undefined` leaves it. */
  heightCm?: number | null;
  usualSize?: string | null;
  shareOnReviews?: boolean;
}

/**
 * «مقاساتي» — her height and usual size.
 *
 * Read by exactly two callers: her, through `/fit-profile`, and the review
 * code at the moment she writes a review or filters by «من بمقاسي». No route
 * serves another woman's profile, and nothing here is copied anywhere except
 * the coarse snapshot she agrees to put on a review.
 */
@Injectable()
export class FitProfileService {
  constructor(private readonly prisma: PrismaService) {}

  async get(userId: string): Promise<FitProfile | null> {
    return this.prisma.fitProfile.findUnique({ where: { userId } });
  }

  /** What «من بمقاسي» compares against, or null when she has not said. */
  async viewerOf(userId: string | undefined): Promise<Viewer | null> {
    if (!userId) return null;
    const profile = await this.get(userId);
    if (!profile) return null;
    return { heightCm: profile.heightCm, usualSize: profile.usualSize };
  }

  async set(userId: string, patch: FitProfilePatch): Promise<FitProfile> {
    const data: { heightCm?: number | null; usualSize?: string | null; shareOnReviews?: boolean } = {};

    if (patch.heightCm !== undefined) {
      if (
        patch.heightCm !== null &&
        (patch.heightCm < HEIGHT_MIN_CM || patch.heightCm > HEIGHT_MAX_CM)
      ) {
        throw new BadRequestException(
          `Height must be between ${HEIGHT_MIN_CM} and ${HEIGHT_MAX_CM} cm`,
        );
      }
      data.heightCm = patch.heightCm;
    }

    if (patch.usualSize !== undefined) {
      if (patch.usualSize === null) {
        data.usualSize = null;
      } else {
        const size = usualSizeOf(patch.usualSize);
        if (!size) throw new BadRequestException('Unknown size');
        data.usualSize = size;
      }
    }

    if (patch.shareOnReviews !== undefined) data.shareOnReviews = patch.shareOnReviews;

    return this.prisma.fitProfile.upsert({
      where: { userId },
      create: { userId, ...data },
      update: data,
    });
  }
}

export function serializeFitProfile(profile: FitProfile | null) {
  return {
    height_cm: profile?.heightCm ?? null,
    usual_size: profile?.usualSize ?? null,
    share_on_reviews: profile?.shareOnReviews ?? true,
    is_set: !!profile && (profile.heightCm != null || profile.usualSize != null),
  };
}
