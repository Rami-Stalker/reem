import {
  CommerceAuthorKind,
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
 * Follow graph.
 *
 * Q31 P1 said customers follow **sellers only**, never each other, and this
 * seed was the only place that rule was ever written down — nothing in the
 * code enforced it, so any caller could already follow any account.
 *
 * The owner replaced it: a shopper's page is private by default and she opts
 * into being followable. So the rule now has a real enforcement point
 * (`UsersService.follow` refuses a private customer) and this writes
 * shopper → boutique edges plus shopper → shopper edges toward the women who
 * have opened their pages. A demo without the second kind cannot show a
 * following feed, which is half of what the feature is.
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

  // Customer → customer edges are written by `seedCustomerContent`, not here:
  // nobody has opened a page yet at this point in the run, and only a woman
  // with an open page may be followed.

  // The foundation seed already wired a few follows, so duplicates are
  // expected rather than exceptional.
  await prisma.follow.createMany({ data: edges, skipDuplicates: true });
}

/**
 * The social layer, on the content platform: posts with a tagged piece,
 * content-only posts, likes, saves, comments and 24h stories.
 *
 * `posts`, `post_likes`, `post_saves`, `comments`, `stories`, `story_views`
 * and `story_reactions` are gone — all seven folded into `commerce_contents`
 * and its satellites. Counters are still written from the rows that were
 * actually created, never invented; see `reconcile.ts`.
 */
export async function seedPosts(
  ctx: DemoContext,
  communityIds: string[],
): Promise<string[]> {
  const { prisma, rng } = ctx;
  const audience = [...ctx.customers.map((c) => c.id), ...communityIds];
  const postIds: string[] = [];

  const engage = async (contentId: string, likes: number, saves: number, comments: number) => {
    for (const userId of rng.sample(audience, likes)) {
      await prisma.commerceContentReaction.create({
        data: { contentId, userId, kind: 'LIKE' },
      });
    }
    for (const userId of rng.sample(audience, saves)) {
      await prisma.commerceContentSave.create({
        data: { contentId, userId, createdAt: rng.pastDate(60) },
      });
    }
    for (const userId of rng.sample(audience, comments)) {
      await prisma.commerceContentComment.create({
        data: {
          contentId,
          userId,
          body: rng.pick(COMMENTS),
          createdAt: rng.pastDate(30),
        },
      });
    }
  };

  // The foundation seed writes a few posts with counter values but no like or
  // comment rows behind them. Reconciliation would zero those counters, so
  // they get real engagement here instead of being left looking dead.
  const foundationPosts = await prisma.commerceContent.findMany({
    where: { contentType: 'product_post' },
    select: { id: true },
  });
  for (const post of foundationPosts) {
    postIds.push(post.id);
    await engage(post.id, rng.int(8, 40), 0, rng.int(1, 6));
  }

  // Q5 P1 — a post may carry one piece, several, or none at all.
  const featuredProducts = rng.sample(ctx.products, 70);

  for (const product of featuredProducts) {
    const seller = product.offers[0]?.sellerId ?? ctx.sellers[0].id;
    const createdAt = rng.pastDate(120, 0);
    const caption = `${rng.pick(POST_CAPTIONS)}\n${product.title}`;

    const post = await prisma.commerceContent.create({
      data: {
        authorId: seller,
        authorKind: CommerceAuthorKind.SELLER,
        authorIsPublic: true,
        contentType: 'product_post',
        body: caption,
        locale: 'ar',
        status: CommerceContentStatus.PUBLISHED,
        moderationStatus: CommerceContentModerationStatus.APPROVED,
        publishedAt: createdAt,
        payload: { caption } as Prisma.InputJsonValue,
        publicationTargets: [
          CommerceContentPublicationChannel.HOME_FEED,
          CommerceContentPublicationChannel.STORE_FEED,
          CommerceContentPublicationChannel.FOLLOWING_FEED,
        ],
        sharesCount: BigInt(rng.int(0, 40)),
        createdAt,
        media: {
          create: [
            {
              url: productImage(product.leaf, `${product.id}-post`),
              type: MediaType.image,
              sortOrder: 0,
            },
          ],
        },
        productTags: {
          create: [
            { productId: product.id, role: 'featured', sortOrder: 0, basis: 'SELLER_OFFER' },
          ],
        },
      },
    });
    postIds.push(post.id);
    await engage(post.id, rng.int(3, 48), rng.int(0, 14), rng.int(0, 7));
  }

  for (const caption of CONTENT_ONLY_CAPTIONS) {
    const seller = rng.pick(ctx.sellers);
    const post = await prisma.commerceContent.create({
      data: {
        authorId: seller.id,
        authorKind: CommerceAuthorKind.SELLER,
        authorIsPublic: true,
        contentType: 'product_post',
        body: caption,
        locale: 'ar',
        status: CommerceContentStatus.PUBLISHED,
        moderationStatus: CommerceContentModerationStatus.APPROVED,
        publishedAt: rng.pastDate(60),
        payload: { caption } as Prisma.InputJsonValue,
        publicationTargets: [
          CommerceContentPublicationChannel.HOME_FEED,
          CommerceContentPublicationChannel.STORE_FEED,
        ],
        sharesCount: BigInt(rng.int(0, 25)),
        createdAt: rng.pastDate(60),
      },
    });
    postIds.push(post.id);
    await engage(post.id, rng.int(5, 30), 0, rng.int(0, 5));
  }

  return postIds;
}

/** Q6 P1 — stories expire after 24h. Expiry is a status, not a deletion. */
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
      const mediaUrl = storyImage(topic, `${seller.id}-${index}`);
      const tagged = rng.bool(0.6);

      const story = await prisma.commerceContent.create({
        data: {
          authorId: seller.id,
          authorKind: CommerceAuthorKind.SELLER,
          authorIsPublic: true,
          contentType: 'story',
          locale: 'ar',
          status: CommerceContentStatus.PUBLISHED,
          moderationStatus: CommerceContentModerationStatus.APPROVED,
          publishedAt: createdAt,
          createdAt,
          expiresAt: new Date(createdAt.getTime() + 24 * 3_600_000),
          payload: {
            frames: [{ media_url: mediaUrl, link: tagged ? `/product/${product.id}` : null }],
          } as Prisma.InputJsonValue,
          publicationTargets: [
            CommerceContentPublicationChannel.STORY_FEED,
            CommerceContentPublicationChannel.STORE_FEED,
          ],
          media: {
            create: [{ url: mediaUrl, type: MediaType.image, sortOrder: 0 }],
          },
          // The product a story points at is a real relation now. It used to be
          // recovered by running a uuid regex over the link on every view.
          ...(tagged
            ? {
                productTags: {
                  create: [
                    { productId: product.id, role: 'featured', sortOrder: 0, basis: 'SELLER_OFFER' },
                  ],
                },
              }
            : {}),
        },
      });

      for (const userId of rng.sample(audience, rng.int(4, 34))) {
        await prisma.commerceContentViewer.create({
          data: { contentId: story.id, userId, firstViewedAt: rng.pastDate(1) },
        });
      }
      for (const userId of rng.sample(audience, rng.int(0, 8))) {
        await prisma.commerceContentReaction.create({
          data: { contentId: story.id, userId, kind: 'EMOJI', emoji: rng.pick(emojis) },
        });
      }
    }
  }

  // A story that has just been posted, with no views yet — the empty-analytics
  // case the seller story dashboard has to render.
  const fresh = ctx.sellers[0];
  const freshUrl = storyImage('boutique,new arrival', `${fresh.id}-fresh`);
  await prisma.commerceContent.create({
    data: {
      authorId: fresh.id,
      authorKind: CommerceAuthorKind.SELLER,
      authorIsPublic: true,
      contentType: 'story',
      locale: 'ar',
      status: CommerceContentStatus.PUBLISHED,
      moderationStatus: CommerceContentModerationStatus.APPROVED,
      publishedAt: new Date(),
      expiresAt: new Date(Date.now() + 23 * 3_600_000),
      payload: { frames: [{ media_url: freshUrl, link: null }] } as Prisma.InputJsonValue,
      publicationTargets: [CommerceContentPublicationChannel.STORY_FEED],
      media: { create: [{ url: freshUrl, type: MediaType.image, sortOrder: 0 }] },
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
    where: { key: { in: ['flash_offer', 'collection', 'live_stream'] } },
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
          authorId: seller.id,
          authorKind: CommerceAuthorKind.SELLER,
          authorIsPublic: true,
          // Campaign formats only. `reel` and `story` are in the registry too
          // and both carry media rules this generic seeder cannot satisfy — a
          // reel with no video would be a row the API itself would refuse.
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

/**
 * What the shoppers themselves have posted, and whose pages they have put
 * other people's posts on.
 *
 * Runs **after** orders, and that ordering is not incidental. A customer may
 * only tag a product that was actually delivered to her, so seeding her
 * content where posts are seeded — before a single order exists — would
 * produce a demo the API itself would refuse to create. If the seed cannot
 * satisfy its own eligibility policy, either the policy or the seed is wrong,
 * and it is better to find that out here.
 *
 * It also opens a few pages. A shopper is private by default, so without this
 * there is nobody to follow, no following feed, and no named promoter on the
 * boutique's screen — and the privacy rule looks like a bug rather than a
 * setting.
 */
export async function seedCustomerContent(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;

  // Roughly half of them open their pages. The other half are what proves the
  // boutique's promoter list can count a woman without naming her.
  const openPages = rng.sample(ctx.customers, Math.ceil(ctx.customers.length / 2));
  for (const customer of openPages) {
    await prisma.user.update({
      where: { id: customer.id },
      data: { profileIsPublic: true, profilePublicSince: rng.pastDate(90, 1) },
    });
  }
  const openIds = new Set(openPages.map((c) => c.id));

  // Now that some pages are open, they can be followed. Only they — the guard
  // in `UsersService.follow` refuses a private customer, so this is also the
  // check that the seed obeys the same rule the API does.
  const followerPool = [
    ...ctx.customers.map((c) => c.id),
    ...ctx.sellers.map((seller) => seller.id),
  ];
  const edges: { followerId: string; followingId: string; createdAt: Date }[] = [];
  for (const target of openPages) {
    for (const followerId of rng.sample(
      followerPool.filter((id) => id !== target.id),
      rng.int(2, 9),
    )) {
      edges.push({
        followerId,
        followingId: target.id,
        createdAt: rng.pastDate(120, 1),
      });
    }
  }
  await prisma.follow.createMany({ data: edges, skipDuplicates: true });

  // What each woman was actually handed. This is the same query the tag policy
  // runs, which is the point: the seed is entitled to exactly what she is.
  const delivered = await prisma.orderItem.findMany({
    where: {
      productId: { not: null },
      sellerOrder: { status: 'DELIVERED' },
    },
    select: {
      id: true,
      productId: true,
      titleSnapshot: true,
      sellerOrder: { select: { order: { select: { userId: true } } } },
    },
  });

  const byCustomer = new Map<string, { orderItemId: string; productId: string; title: string }[]>();
  for (const line of delivered) {
    const userId = line.sellerOrder.order.userId;
    if (!userId || !line.productId) continue;
    const bucket = byCustomer.get(userId) ?? [];
    bucket.push({ orderItemId: line.id, productId: line.productId, title: line.titleSnapshot });
    byCustomer.set(userId, bucket);
  }

  const captions = [
    'لبستها اليوم وحبيتها كتير 💕',
    'وصلتني وكانت أحلى من الصور 🌸',
    'إطلالة اليوم — القماش خيال',
    'ثاني مرة أطلب من نفس المتجر، ما بيخيّب',
  ];

  const contentIds: string[] = [];
  for (const [userId, lines] of byCustomer) {
    if (!rng.bool(0.55)) continue;
    const line = rng.pick(lines);
    const caption = rng.pick(captions);
    const createdAt = rng.pastDate(45, 0);

    const content = await prisma.commerceContent.create({
      data: {
        authorId: userId,
        authorKind: CommerceAuthorKind.CUSTOMER,
        authorIsPublic: openIds.has(userId),
        contentType: 'product_post',
        body: caption,
        locale: 'ar',
        status: CommerceContentStatus.PUBLISHED,
        moderationStatus: CommerceContentModerationStatus.APPROVED,
        publishedAt: createdAt,
        createdAt,
        payload: { caption } as Prisma.InputJsonValue,
        publicationTargets: [
          CommerceContentPublicationChannel.HOME_FEED,
          CommerceContentPublicationChannel.FOLLOWING_FEED,
        ],
        media: {
          create: [
            {
              url: storyImage('outfit,dress', `${userId}-look`),
              type: MediaType.image,
              sortOrder: 0,
            },
          ],
        },
        // `PURCHASE`, with the delivered line recorded as the proof — exactly
        // what the API would have written.
        productTags: {
          create: [
            {
              productId: line.productId,
              role: 'featured',
              sortOrder: 0,
              basis: 'PURCHASE',
              sourceOrderItemId: line.orderItemId,
            },
          ],
        },
      },
    });
    contentIds.push(content.id);
  }

  // One piece under review, because a shopper's first posts are — and a
  // moderation queue with nothing in it cannot be looked at.
  const reviewer = ctx.customers[0];
  const reviewerLines = byCustomer.get(reviewer.id);
  if (reviewerLines?.length) {
    await prisma.commerceContent.create({
      data: {
        authorId: reviewer.id,
        authorKind: CommerceAuthorKind.CUSTOMER,
        authorIsPublic: openIds.has(reviewer.id),
        contentType: 'product_post',
        body: 'أول منشور إلي هون 🌷',
        locale: 'ar',
        status: CommerceContentStatus.IN_REVIEW,
        moderationStatus: CommerceContentModerationStatus.PENDING,
        payload: { caption: 'أول منشور إلي هون 🌷' } as Prisma.InputJsonValue,
        publicationTargets: [CommerceContentPublicationChannel.HOME_FEED],
      },
    });
  }

  // ── «أضيفي إلى صفحتي» ────────────────────────────────────────────────────
  // Boutique posts that shoppers have put on their own pages. Deliberately
  // seeded from BOTH open and closed pages, so the promoter screen has the
  // named case and the anonymous one on day one — the privacy rule is not
  // demonstrable with only one of them.
  const sellerPosts = await prisma.commerceContent.findMany({
    where: { authorKind: CommerceAuthorKind.SELLER, contentType: 'product_post', status: 'PUBLISHED' },
    select: { id: true, authorId: true },
    take: 40,
  });

  for (const customer of ctx.customers) {
    for (const post of rng.sample(sellerPosts, rng.int(0, 3))) {
      if (post.authorId === customer.id) continue;
      const createdAt = rng.pastDate(40, 0);
      await prisma.commerceContentReshare.upsert({
        where: {
          sourceContentId_resharerId: {
            sourceContentId: post.id,
            resharerId: customer.id,
          },
        },
        create: {
          sourceContentId: post.id,
          resharerId: customer.id,
          sourceAuthorId: post.authorId,
          resharerIsPublic: openIds.has(customer.id),
          note: rng.bool(0.4) ? 'لقيتها هون 💕' : null,
          createdAt,
        },
        update: {},
      });
      await prisma.commerceContent.update({
        where: { id: post.id },
        data: { sharesCount: { increment: 1 } },
      });
    }
  }
}
