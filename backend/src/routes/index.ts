import { Router } from 'express';
import { authRouter } from '../modules/auth/auth.routes.js';
import { usersRouter } from '../modules/users/users.routes.js';
import { postsRouter } from '../modules/posts/posts.routes.js';
import { storiesRouter } from '../modules/stories/stories.routes.js';
import { productsRouter } from '../modules/products/products.routes.js';
import { ordersRouter } from '../modules/orders/orders.routes.js';
import { favoritesRouter } from '../modules/favorites/favorites.routes.js';
import { chatsRouter } from '../modules/chats/chats.routes.js';
import {
  addressesRouter,
  couponsRouter,
  rewardsRouter,
  notificationsRouter,
  paymentMethodsRouter,
} from '../modules/settings/settings.routes.js';
import { adminRouter } from '../modules/admin/admin.routes.js';

export const apiRouter = Router();

apiRouter.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

apiRouter.use('/auth', authRouter);
apiRouter.use('/users', usersRouter);
apiRouter.use('/posts', postsRouter);
apiRouter.use('/stories', storiesRouter);
apiRouter.use('/products', productsRouter);
apiRouter.use('/orders', ordersRouter);
apiRouter.use('/favorites', favoritesRouter);
apiRouter.use('/chats', chatsRouter);
apiRouter.use('/addresses', addressesRouter);
apiRouter.use('/coupons', couponsRouter);
apiRouter.use('/rewards', rewardsRouter);
apiRouter.use('/notifications', notificationsRouter);
apiRouter.use('/payment-methods', paymentMethodsRouter);
apiRouter.use('/admin', adminRouter);
