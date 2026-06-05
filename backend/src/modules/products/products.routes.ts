import { Router } from 'express';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma.js';
import { NotFoundError } from '../../lib/errors.js';
import { asyncHandler } from '../../middleware/error-handler.js';
import { requireAuth, type AuthRequest } from '../../middleware/auth.js';
import { validateBody } from '../../middleware/validate.js';
import { paramId } from '../../utils/params.js';
import { serializeProduct } from '../../utils/serializers.js';

const productInclude = {
  seller: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
};

const counterSchema = z.object({
  amount: z.number().int().min(1).max(1000).optional(),
});

const stockSchema = z.object({
  quantity: z.number().int().min(1).max(1000),
});

type ProductOrderBy = Prisma.ProductOrderByWithRelationInput[];

const availableWhere: Prisma.ProductWhereInput = {
  isAvailable: true,
  stock: { gt: 0 },
};

export const productsRouter = Router();

function pagination(query: AuthRequest['query']) {
  const page = Math.max(1, parseInt(String(query.page ?? '1'), 10) || 1);
  const limit = Math.min(
    50,
    Math.max(1, parseInt(String(query.limit ?? '20'), 10) || 20),
  );
  return { page, limit, skip: (page - 1) * limit };
}

function buildFilters(query: AuthRequest['query']): Prisma.ProductWhereInput {
  const minPrice = query.min_price ? Number(query.min_price) : undefined;
  const maxPrice = query.max_price ? Number(query.max_price) : undefined;
  const featured = query.featured === undefined
    ? undefined
    : String(query.featured) === 'true';

  return {
    ...availableWhere,
    ...(featured !== undefined ? { isFeatured: featured } : {}),
    ...(minPrice !== undefined || maxPrice !== undefined
      ? {
          price: {
            ...(minPrice !== undefined ? { gte: minPrice } : {}),
            ...(maxPrice !== undefined ? { lte: maxPrice } : {}),
          },
        }
      : {}),
  };
}

async function findProducts({
  where = availableWhere,
  orderBy,
  take = 20,
  skip = 0,
}: {
  where?: Prisma.ProductWhereInput;
  orderBy: ProductOrderBy;
  take?: number;
  skip?: number;
}) {
  return prisma.product.findMany({
    where,
    orderBy,
    skip,
    take,
    include: productInclude,
  });
}

async function favoriteSet(userId: string, productIds: string[]) {
  if (productIds.length === 0) return new Set<string>();

  const favorites = await prisma.favorite.findMany({
    where: { userId, productId: { in: productIds } },
    select: { productId: true },
  });
  return new Set(favorites.map((f) => f.productId));
}

async function serializeList(products: Awaited<ReturnType<typeof findProducts>>, userId: string) {
  const favSet = await favoriteSet(userId, products.map((p) => p.id));
  return products.map((p) => serializeProduct(p, { isLiked: favSet.has(p.id) }));
}

async function paginatedProducts(req: AuthRequest, where: Prisma.ProductWhereInput, orderBy: ProductOrderBy) {
  const { page, limit, skip } = pagination(req.query);
  const [products, total] = await Promise.all([
    findProducts({ where, orderBy, take: limit, skip }),
    prisma.product.count({ where }),
  ]);

  return {
    data: await serializeList(products, req.user!.id),
    pagination: {
      page,
      limit,
      total,
      total_pages: Math.ceil(total / limit),
      has_next_page: skip + products.length < total,
    },
  };
}

productsRouter.get(
  '/home',
  asyncHandler(async (req: AuthRequest, res) => {
    const [trending, newArrivals, featured, mostLoved, forYou] = await Promise.all([
      findProducts({ orderBy: [{ ordersCount: 'desc' }, { viewsCount: 'desc' }], take: 12 }),
      findProducts({ orderBy: [{ createdAt: 'desc' }], take: 12 }),
      findProducts({
        where: { ...availableWhere, isFeatured: true },
        orderBy: [{ createdAt: 'desc' }],
        take: 12,
      }),
      findProducts({ orderBy: [{ favoritesCount: 'desc' }, { rating: 'desc' }], take: 12 }),
      findProducts({
        where: { ...availableWhere, showInFeed: true },
        orderBy: [{ rating: 'desc' }, { createdAt: 'desc' }],
        take: 12,
      }),
    ]);

    const userId = req.user?.id;

    const serializeMaybeLiked = async (list: typeof trending) => {
      if (!userId) {
        return list.map((p) => serializeProduct(p, { isLiked: false }));
      }
      return serializeList(list, userId);
    };

    res.json({
      trending: await serializeMaybeLiked(trending),
      new_arrivals: await serializeMaybeLiked(newArrivals),
      featured: await serializeMaybeLiked(featured),
      most_loved: await serializeMaybeLiked(mostLoved),
      for_you: await serializeMaybeLiked(forYou),
    });
  }),
);



productsRouter.get(
  '/trending',
  asyncHandler(async (req: AuthRequest, res) => {
    const products = await findProducts({
      orderBy: [{ ordersCount: 'desc' }, { viewsCount: 'desc' }],
      take: 20,
    });

    const userId = req.user?.id;
    res.json(
      userId
        ? await serializeList(products, userId)
        : products.map((p) => serializeProduct(p, { isLiked: false })),
    );
  }),
);

productsRouter.get(
  '/new-arrivals',
  asyncHandler(async (req: AuthRequest, res) => {
    const products = await findProducts({
      orderBy: [{ createdAt: 'desc' }],
      take: 20,
    });
    const userId = req.user?.id;
    res.json(
      userId
        ? await serializeList(products, userId)
        : products.map((p) => serializeProduct(p, { isLiked: false })),
    );
  }),
);

productsRouter.get(
  '/featured',
  asyncHandler(async (req: AuthRequest, res) => {
    const products = await findProducts({
      where: { ...availableWhere, isFeatured: true },
      orderBy: [{ createdAt: 'desc' }],
      take: 20,
    });
    const userId = req.user?.id;
    res.json(
      userId
        ? await serializeList(products, userId)
        : products.map((p) => serializeProduct(p, { isLiked: false })),
    );
  }),
);

productsRouter.get(
  '/most-loved',
  asyncHandler(async (req: AuthRequest, res) => {
    const products = await findProducts({
      orderBy: [{ favoritesCount: 'desc' }, { createdAt: 'desc' }],
      take: 20,
    });
    const userId = req.user?.id;
    res.json(
      userId
        ? await serializeList(products, userId)
        : products.map((p) => serializeProduct(p, { isLiked: false })),
    );
  }),
);

productsRouter.get(
  '/top-rated',
  asyncHandler(async (req: AuthRequest, res) => {
    const products = await findProducts({
      orderBy: [{ rating: 'desc' }, { reviewsCount: 'desc' }],
      take: 20,
    });
    const userId = req.user?.id;
    res.json(
      userId
        ? await serializeList(products, userId)
        : products.map((p) => serializeProduct(p, { isLiked: false })),
    );
  }),
);

productsRouter.get(
  '/search',
  asyncHandler(async (req: AuthRequest, res) => {
    const q = String(req.query.q ?? '').trim();
    const where: Prisma.ProductWhereInput = {
      ...buildFilters(req.query),
      ...(q
        ? {
            OR: [
              { title: { contains: q, mode: 'insensitive' } },
              { description: { contains: q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const userId = req.user?.id;
    if (!userId) {
      // Public: same pagination structure, but no isLiked.
      const { page, limit, skip } = pagination(req.query);
      const [products, total] = await Promise.all([
        findProducts({
          where,
          orderBy: [{ createdAt: 'desc' }],
          take: limit,
          skip,
        }),
        prisma.product.count({ where }),
      ]);

      res.json({
        data: products.map((p) => serializeProduct(p, { isLiked: false })),
        pagination: {
          page,
          limit,
          total,
          total_pages: Math.ceil(total / limit),
          has_next_page: skip + products.length < total,
        },
      });
      return;
    }

    res.json(await paginatedProducts(req, where, [{ createdAt: 'desc' }]));
  }),
);

productsRouter.get(
  '/category/:category/trending',
  asyncHandler(async (req: AuthRequest, res) => {
    const category = String(req.params.category).toLowerCase();
    const where = { ...buildFilters(req.query), category };

    const userId = req.user?.id;
    if (!userId) {
      const { page, limit, skip } = pagination(req.query);
      const [products, total] = await Promise.all([
        findProducts({
          where,
          orderBy: [{ ordersCount: 'desc' }, { createdAt: 'desc' }],
          take: limit,
          skip,
        }),
        prisma.product.count({ where }),
      ]);

      res.json({
        data: products.map((p) => serializeProduct(p, { isLiked: false })),
        pagination: {
          page,
          limit,
          total,
          total_pages: Math.ceil(total / limit),
          has_next_page: skip + products.length < total,
        },
      });
      return;
    }

    res.json(
      await paginatedProducts(
        req,
        where,
        [{ ordersCount: 'desc' }, { createdAt: 'desc' }],
      ),
    );
  }),
);

productsRouter.get(
  '/category/:category/new-arrivals',
  asyncHandler(async (req: AuthRequest, res) => {
    const category = String(req.params.category).toLowerCase();
    const where = { ...buildFilters(req.query), category };

    const userId = req.user?.id;
    if (!userId) {
      const { page, limit, skip } = pagination(req.query);
      const [products, total] = await Promise.all([
        findProducts({
          where,
          orderBy: [{ createdAt: 'desc' }],
          take: limit,
          skip,
        }),
        prisma.product.count({ where }),
      ]);

      res.json({
        data: products.map((p) => serializeProduct(p, { isLiked: false })),
        pagination: {
          page,
          limit,
          total,
          total_pages: Math.ceil(total / limit),
          has_next_page: skip + products.length < total,
        },
      });
      return;
    }

    res.json(await paginatedProducts(req, where, [{ createdAt: 'desc' }]));
  }),
);

productsRouter.get(
  '/category/:category',
  asyncHandler(async (req: AuthRequest, res) => {
    const category = String(req.params.category).toLowerCase();
    const where = { ...buildFilters(req.query), category };

    const userId = req.user?.id;
    if (!userId) {
      const { page, limit, skip } = pagination(req.query);
      const [products, total] = await Promise.all([
        findProducts({
          where,
          orderBy: [{ createdAt: 'desc' }],
          take: limit,
          skip,
        }),
        prisma.product.count({ where }),
      ]);

      res.json({
        data: products.map((p) => serializeProduct(p, { isLiked: false })),
        pagination: {
          page,
          limit,
          total,
          total_pages: Math.ceil(total / limit),
          has_next_page: skip + products.length < total,
        },
      });
      return;
    }

    res.json(await paginatedProducts(req, where, [{ createdAt: 'desc' }]));
  }),
);

productsRouter.get(
  '/',
  asyncHandler(async (req: AuthRequest, res) => {
    // Public list endpoint: skip isLiked when unauthenticated.
    const userId = req.user?.id;
    if (!userId) {
      const where = buildFilters(req.query);
      const { page, limit, skip } = pagination(req.query);
      const [products, total] = await Promise.all([
        findProducts({
          where,
          orderBy: [{ createdAt: 'desc' }],
          take: limit,
          skip,
        }),
        prisma.product.count({ where }),
      ]);
      res.json({
        data: products.map((p) => serializeProduct(p, { isLiked: false })),
        pagination: {
          page,
          limit,
          total,
          total_pages: Math.ceil(total / limit),
          has_next_page: skip + products.length < total,
        },
      });
      return;
    }

    res.json(await paginatedProducts(req, buildFilters(req.query), [{ createdAt: 'desc' }]));
  }),
);


productsRouter.get(
  '/:id',
  asyncHandler(async (req: AuthRequest, res) => {
    const id = paramId(req.params.id);
    const product = await prisma.product.update({
      where: { id },
      data: { viewsCount: { increment: 1 } },
      include: productInclude,
    }).catch(() => null);
    if (!product) throw new NotFoundError('Product not found');

    const userId = req.user?.id;
    if (!userId) {
      return res.json(serializeProduct(product, { isLiked: false }));
    }

    const favSet = await favoriteSet(userId, [product.id]);
    res.json(serializeProduct(product, { isLiked: favSet.has(product.id) }));
  }),
);


productsRouter.post('/:id/views', requireAuth, asyncHandler(async (req, res) => {
  await prisma.product.update({
    where: { id: paramId(req.params.id) },
    data: { viewsCount: { increment: 1 } },
  });
  res.json({ message: 'View recorded' });
}));

productsRouter.post('/:id/orders', requireAuth, validateBody(counterSchema), asyncHandler(async (req, res) => {
  await prisma.product.update({
    where: { id: paramId(req.params.id) },
    data: { ordersCount: { increment: req.body.amount ?? 1 } },
  });
  res.json({ message: 'Order count updated' });
}));

productsRouter.post('/:id/stock/reduce', requireAuth, validateBody(stockSchema), asyncHandler(async (req, res) => {
  await prisma.product.update({
    where: { id: paramId(req.params.id) },
    data: { stock: { decrement: req.body.quantity } },
  });
  res.json({ message: 'Stock updated' });
}));
