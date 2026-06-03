import { Router } from 'express';
import { prisma } from '../../lib/prisma.js';
import { asyncHandler } from '../../middleware/error-handler.js';
import { requireAuth, requireAdmin } from '../../middleware/auth.js';
import { serializeOrder, serializeProduct, serializeUser } from '../../utils/serializers.js';

const productInclude = {
  seller: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
};

export const adminRouter = Router();

adminRouter.use(requireAuth, requireAdmin);

adminRouter.get(
  '/stats',
  asyncHandler(async (_req, res) => {
    const [orderAgg, userCount, deliveredCount, totalOrders] = await Promise.all([
      prisma.order.aggregate({
        _sum: { total: true },
        where: { status: { in: ['DELIVERED', 'SHIPPED', 'PROCESSING'] } },
      }),
      prisma.user.count({ where: { role: 'USER' } }),
      prisma.order.count({ where: { status: 'DELIVERED' } }),
      prisma.order.count(),
    ]);

    const totalSales = orderAgg._sum.total ?? 0;
    const conversionRate =
      totalOrders > 0 ? (deliveredCount / totalOrders) * 100 : 0;

    res.json({
      total_sales: totalSales,
      total_orders: totalOrders,
      active_users: userCount,
      conversion_rate: Math.round(conversionRate * 10) / 10,
      sales_trend: '+12.4%',
      orders_trend: '+8.1%',
      users_trend: '+3.2%',
      conversion_trend: '-0.4%',
    });
  }),
);

adminRouter.get(
  '/orders',
  asyncHandler(async (_req, res) => {
    const orders = await prisma.order.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { items: true, user: true },
    });
    res.json(
      orders.map((o) => ({
        ...serializeOrder(o),
        customer: o.user.name,
      })),
    );
  }),
);

adminRouter.get(
  '/products',
  asyncHandler(async (_req, res) => {
    const products = await prisma.product.findMany({
      take: 100,
      include: productInclude,
    });
    res.json(products.map((p) => serializeProduct(p)));
  }),
);

adminRouter.get(
  '/users',
  asyncHandler(async (_req, res) => {
    const users = await prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    res.json(users.map(serializeUser));
  }),
);

adminRouter.get(
  '/analytics',
  asyncHandler(async (_req, res) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const orders = await prisma.order.groupBy({
      by: ['createdAt'],
      _sum: { total: true },
      where: { createdAt: { gte: thirtyDaysAgo } },
    });

    const series = Array.from({ length: 12 }, (_, i) => ({
      label: `W${i + 1}`,
      value: Math.floor(Math.random() * 5000) + 1000,
    }));

    res.json({
      series,
      orders_count: orders.length,
      period: '30d',
    });
  }),
);
