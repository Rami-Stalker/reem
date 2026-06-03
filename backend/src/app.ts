// import express from 'express';
// import cors from 'cors';
// import helmet from 'helmet';
// import rateLimit from 'express-rate-limit';
// import { pinoHttp } from 'pino-http';
// // import { env, isDev } from './config/env.js';
// import { logger } from './lib/logger.js';
// import { apiRouter } from './routes/index.js';
// import { errorHandler } from './middleware/error-handler.js';

// export function createApp() {
//   const app = express();

//   app.use(helmet());
//   app.use(
//     cors({
//       origin: env.CORS_ORIGINS === '*' ? true : env.CORS_ORIGINS.split(','),
//       credentials: true,
//     }),
//   );
//   app.use(express.json({ limit: '2mb' }));
//   app.use(
//     pinoHttp({
//       logger,
//       autoLogging: isDev,
//     }),
//   );

//   const limiter = rateLimit({
//     windowMs: env.RATE_LIMIT_WINDOW_MS,
//     max: env.RATE_LIMIT_MAX,
//     standardHeaders: true,
//     legacyHeaders: false,
//     message: { message: 'Too many requests', error: 'RATE_LIMIT' },
//   });
//   app.use(limiter);

//   const authLimiter = rateLimit({
//     windowMs: env.RATE_LIMIT_WINDOW_MS,
//     max: env.AUTH_RATE_LIMIT_MAX,
//     message: { message: 'Too many auth attempts', error: 'AUTH_RATE_LIMIT' },
//   });

//   app.use(env.API_PREFIX, (req, res, next) => {
//     if (req.path.startsWith('/auth/login') || req.path.startsWith('/auth/register')) {
//       authLimiter(req, res, next);
//       return;
//     }
//     next();
//   });

//   app.use(env.API_PREFIX, apiRouter);

//   app.use(errorHandler);

//   return app;
// }
