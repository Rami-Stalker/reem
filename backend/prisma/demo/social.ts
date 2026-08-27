import {
  CommerceContentModerationStatus,
  CommerceContentPublicationChannel,
  CommerceContentStatus,
  MediaType,
  Prisma,
} from '@prisma/client';
import {
  COMMENTS,
  CONTENT_ONLY_CAPTIONS,
  LEAVES,
  POST_CAPTIONS,
} from './data';
import { productImage, storyImage } from './media';
import { DemoContext } from './context';

/**
 * Follow graph. Q31 P1 is explicit: customers follow **sellers only**, never
 * each other — so this only ever writes shopper → boutique edges (plus a few
 * boutique → boutique ones, which the rule does allow).
 */
export async function seedFollows(
  ctx: DemoContext,
  communityIds: string[],
): Promise<void> {
  const { prisma, rng } = ctx;
  const followers = [...ctx.customers.map((c) => c.id), ...communityIds];
  const edges: { followerId: string; followingId: string; createdAt: Date }[] =
    [];

  for (const followerId of followers) {
    for (const seller of rng.sample(ctx.sellers, rng.int(1, 6))) {
      edges.push({
        followerId,
        followingId: seller.id,
        createdAt: rng.pastDate(200, 1),
      });
    }
  }

  // Boutiques keeping an eye on each other.
  for (const seller of ctx.sellers) {
    for (const other of rng.sample(
      ctx.sellers.filter((s) => s.id !== seller.id),
      rng.int(0, 2),
    )) {
      edges.push({
        followerId: seller.id,
        followingId: other.id,
        createdAt: rng.pastDate(200, 1),
      });
    }
  }

  // The foundation seed already wired a few follows, so duplicates are
  // expected rather than exceptional.
  await prisma.follow.createMany({ data: edges, skipDuplicates: true });
}

/**
 * The social layer: product posts, content-only posts, likes, saves, comments,
 * and 24h stories. Counters are written from the rows that were actually
 * created, never invented — see `reconcile.ts`.
 */
export async function seedPosts(
  ctx: DemoContext,
  communityIds: string[],
): Promise<string[]> {
  const { prisma, rng } = ctx;
  const audience = [...ctx.customers.map((c) => c.id), ...communityIds];
  const postIds: string[] = [];

  // The foundation seed writes a few posts with counter values but no like or
  // comment rows behind them. Reconciliation would zero those counters, so
  // they get real engagement here instead of being left looking dead.
  const foundationPosts = await prisma.post.findMany({ select: { id: true } });
  for (const post of foundationPosts) {
    postIds.push(post.id);
    for (const userId of rng.sample(audience, rng.int(8, 40))) {
      await prisma.postLike.create({ data: { postId: post.id, userId } });
    }
    for (const userId of rng.sample(audience, rng.int(1, 6))) {
      await prisma.comment.create({
        data: {
          postId: post.id,
          userId,
          content: rng.pick(COMMENTS),
          createdAt: rng.pastDate(20),
        },
      });
    }
  }

  // Q5 P1 — a post may carry one product, or be pure content.
  const featuredProducts = rng.sample(ctx.products, 70);

  for (const product of featuredProducts) {
    const seller = product.offers[0]?.sellerId ?? ctx.sellers[0].id;
    const createdAt = rng.pastDate(120, 0);

    const post = await prisma.post.create({
      data: {
        authorId: seller,
        productId: product.id,
        caption: `${rng.pick(POST_CAPTIONS)}\n${product.title}`,
        sharesCount: rng.int(0, 40),
        createdAt,
      },
    });
    postIds.push(post.id);

    for (const userId of rng.sample(audience, rng.int(3, 48))) {
      await prisma.postLike.create({ data: { postId: post.id, userId } });
    }
    for (const userId of rng.sample(audience, rng.int(0, 14))) {
      await prisma.postSave.create({
        data: { postId: post.id, userId, createdAt: rng.pastDate(60) },
      });
    }
    for (const userId of rng.sample(audience, rng.int(0, 7))) {
      await prisma.comment.create({
        data: {
          postId: post.id,
          userId,
          content: rng.pick(COMMENTS),
          createdAt: rng.pastDate(30),
        },
      });
    }
  }

  for (const caption of CONTENT_ONLY_CAPTIONS) {
    const seller = rng.pick(ctx.sellers);
    const post = await prisma.post.create({
      data: {
        authorId: seller.id,
        caption,
        sharesCount: rng.int(0, 25),
        createdAt: rng.pastDate(60),
      },
    });
    postIds.push(post.id);

    for (const userId of rng.sample(audience, rng.int(5, 30))) {
      await prisma.postLike.create({ data: { postId: post.id, userId } });
    }
    for (const userId of rng.sample(audience, rng.int(0, 5))) {
      await prisma.comment.create({
        data: { postId: post.id, userId, content: rng.pick(COMMENTS) },
      });
    }
  }

  return postIds;
}

/** Q6 P1 — stories expire after 24h; the cleanup cron deletes them. */
export async function seedStories(
  ctx: DemoContext,
  communityIds: string[],
): Promise<void> {
  const { prisma, rng } = ctx;
  const audience = [...ctx.customers.map((c) => c.id), ...communityIds];
  const emojis = ['❤️', '😍', '🔥', '👏', '🌸', '💕'];

  for (const seller of ctx.sellers) {
    for (let index = 0; index < rng.int(1, 3); index += 1) {
      // Posted somewhere in the last 20 hours, so the whole rail is still live.
      const hoursAgo = rng.int(1, 20);
      const createdAt = new Date(Date.now() - hoursAgo * 3_600_000);
      const product = rng.pick(ctx.products);
      const topic = LEAVES[product.leaf]?.topic ?? 'fashion';

      const story = await prisma.story.create({
        data: {
          userId: seller.id,
          mediaUrl: storyImage(topic, `${seller.id}-${index}`),
          mediaType: MediaType.image,
          link: rng.bool(0.6) ? `/product/${product.id}` : null,
          createdAt,
          expiresAt: new Date(createdAt.getTime() + 24 * 3_600_000),
        },
      });

      for (const userId of rng.sample(audience, rng.int(4, 34))) {
        await prisma.storyView.create({
          data: { storyId: story.id, userId, viewedAt: rng.pastDate(1) },
        });
      }
      for (const userId of rng.sample(audience, rng.int(0, 8))) {
        await prisma.storyReaction.create({
          data: { storyId: story.id, userId, emoji: rng.pick(emojis) },
        });
      }
    }
  }

  // A story that has just been posted, with no views yet — the empty-analytics
  // case the seller story dashboard has to render.
  const fresh = ctx.sellers[0];
  await prisma.story.create({
    data: {
      userId: fresh.id,
      mediaUrl: storyImage('boutique,new arrival', `${fresh.id}-fresh`),
      link: null,
      expiresAt: new Date(Date.now() + 23 * 3_600_000),
    },
  });
}

/**
 * `CommerceContent` is the richer content engine that backs multi-product
 * posts, scheduling and moderation — the shape Q5 P1 calls "one post, several
 * tagged products", which the flat `Post` row cannot express.
 */
export async function seedCommerceContent(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;

  const types = await prisma.commerceContentTypeDefinition.findMany({
    select: { key: true },
  });
  if (types.length === 0) return;

  for (const seller of ctx.sellers) {
    for (let index = 0; index < rng.int(1, 3); index += 1) {
      const tagged = rng.sample(
        ctx.products.filter((product) =>
          product.offers.some((offer) => offer.sellerId === seller.id),
        ),
        rng.int(2, 4),
      );
      if (tagged.length < 2) continue;

      const publishedAt = rng.pastDate(90, 1);
      const status = rng.weighted<CommerceContentStatus>([
        [CommerceContentStatus.PUBLISHED, 6],
        [CommerceContentStatus.SCHEDULED, 1],
        [CommerceContentStatus.DRAFT, 1],
      ]);

      const views = rng.int(200, 9_000);
      const content = await prisma.commerceContent.create({
        data: {
          sellerId: seller.id,
          contentType: rng.pick(types).key,
          title: `إطلالة ${index + 1} من ${seller.store}`,
          body: 'تشكيلة متكاملة اخترناها لكِ — كل القطع متوفرة الآن.',
          locale: 'ar',
          status,
          moderationStatus:
            status === CommerceContentStatus.PUBLISHED
              ? CommerceContentModerationStatus.APPROVED
              : CommerceContentModerationStatus.PENDING,
          payload: {
            layout: 'carousel',
            products: tagged.map((product) => product.id),
          } as Prisma.InputJsonValue,
          publicationTargets: [
            CommerceContentPublicationChannel.HOME_FEED,
            CommerceContentPublicationChannel.STORE_FEED,
          ],
          publishedAt:
            status === CommerceContentStatus.PUBLISHED ? publishedAt : null,
          scheduledAt:
            status === CommerceContentStatus.SCHEDULED
              ? rng.futureDate(14, 1)
              : null,
          impressionsCount: BigInt(views * rng.int(2, 5)),
          viewsCount: BigInt(views),
          uniqueViewersCount: BigInt(Math.round(views * 0.72)),
          engagementCount: BigInt(Math.round(views * rng.float(0.05, 0.2))),
          productClicksCount: BigInt(Math.round(views * rng.float(0.02, 0.12))),
          savesCount: BigInt(rng.int(0, 120)),
          sharesCount: BigInt(rng.int(0, 60)),
          lastEngagementAt: rng.pastDate(10),
          media: {
            create: tagged.map((product, order) => ({
              url: productImage(
                LEAVES[product.leaf]?.topic ?? 'fashion',
                `content-${seller.id}-${index}-${order}`,
              ),
              type: MediaType.image,
              altText: product.title,
              sortOrder: order,
            })),
          },
          productTags: {
            create: tagged.map((product, order) => ({
              productId: product.id,
              role: order === 0 ? 'featured' : 'mentioned',
              displayLabel: product.title,
              x: rng.float(0.2, 0.8),
              y: rng.float(0.2, 0.8),
              sortOrder: order,
            })),
          },
        },
      });

      await prisma.commerceContentVersion.create({
        data: {
          contentId: content.id,
          version: 1,
          snapshot: { title: content.title, body: content.body },
          changeNote: 'النسخة الأولى',
          createdById: seller.id,
        },
      });
    }
  }
}
