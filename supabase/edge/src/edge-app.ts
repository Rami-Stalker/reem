import { LogLevel, ValidationPipe } from '@nestjs/common';
import { ExpressAdapter, NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import compression from 'compression';
import type { NextFunction, Request, Response } from 'express';
import helmet from 'helmet';
import { AppModule } from '../../../backend/src/app.module';
import { AllExceptionsFilter } from '../../../backend/src/common/filters/all-exceptions.filter';
import { RequestContextMiddleware } from '../../../backend/src/common/observability/request-context.middleware';
import { StructuredLogger } from '../../../backend/src/common/observability/structured-logger';
import { OtpService } from '../../../backend/src/modules/auth/otp.service';
import { ChatRealtimeGateway } from '../../../backend/src/modules/chats/chat-realtime.gateway';
import { ImageDerivativesService } from '../../../backend/src/modules/media/image-derivatives';
import { MediaService } from '../../../backend/src/modules/media/media.service';
import { MEDIA_STORAGE_DRIVER } from '../../../backend/src/modules/media/storage/media-storage.driver';
import { ValueCollectorService } from '../../../backend/src/modules/value/value-collector.service';
import { SupabaseAwareOtpService } from './identity/supabase-aware-otp.service';
import { EdgeValueCollectorService } from './scheduling/edge-value-collector.service';
import { SupabaseRealtimeGateway } from './realtime/supabase-realtime.gateway';
import { SupabaseRuntime } from './runtime/env';
import { imageEngineGate } from './runtime/image-engine';
import { trackRequests } from './runtime/keep-warm';
import { EdgeImageDerivativesService } from './storage/edge-image-derivatives.service';
import { EdgeMediaService } from './storage/edge-media.service';
import { SupabaseStorageDriver } from './storage/supabase-storage.driver';
import { SupabaseBridgeModule } from './supabase-bridge.module';

function logLevels(): LogLevel[] {
  // Supabase keeps at most 100 log events per 10 seconds per function. Nest
  // logs a line per route at boot — 668 of them — so `log` is opt-in.
  const configured = process.env.REEM_LOG_LEVELS;
  if (!configured) return ['error', 'warn'];
  return configured.split(',').map((level) => level.trim()) as LogLevel[];
}

/**
 * The Reem API application, assembled for the edge.
 *
 * `AppModule` is imported whole — all 49 feature modules, every guard,
 * interceptor and policy — and exactly five providers are swapped, each for a
 * subclass or implementation of the backend's own seam:
 *
 *   MEDIA_STORAGE_DRIVER     local disk          → Supabase Storage buckets
 *   MediaService             one media origin    → Storage for public, function for private
 *   ImageDerivativesService  libvips resizing    → originals only (no native code on the edge)
 *   ChatRealtimeGateway      in-process sockets  → Supabase Realtime broadcast
 *   OtpService               codes only          → codes, or a Supabase login proof
 *
 * The HTTP setup mirrors `backend/src/main.ts` line for line, minus the local
 * static media mount, which Storage replaces.
 */
export async function createEdgeApp(runtime: SupabaseRuntime): Promise<NestExpressApplication> {
  const moduleRef = await Test.createTestingModule({
    imports: [AppModule, SupabaseBridgeModule],
  })
    .overrideProvider(MEDIA_STORAGE_DRIVER)
    .useClass(SupabaseStorageDriver)
    .overrideProvider(MediaService)
    .useClass(EdgeMediaService)
    .overrideProvider(ImageDerivativesService)
    .useClass(EdgeImageDerivativesService)
    .overrideProvider(ChatRealtimeGateway)
    .useClass(SupabaseRealtimeGateway)
    .overrideProvider(OtpService)
    .useClass(SupabaseAwareOtpService)
    .overrideProvider(ValueCollectorService)
    .useClass(EdgeValueCollectorService)
    .compile();

  const app = moduleRef.createNestApplication<NestExpressApplication>(new ExpressAdapter(), {
    rawBody: true,
    logger: new StructuredLogger('Reem'),
  });
  app.useLogger(logLevels());

  const publicBase = new URL(runtime.url);
  const functionPrefix = `/${runtime.functionName}`;
  const publicProtocol = publicBase.protocol.replace(':', '');

  // Requests reach the function as `/api/<route>`. Routing sees `/<route>`,
  // exactly as on a server; anything that reconstructs the URL the client
  // called — device proofs sign it — sees the public one:
  // `https://<project>.supabase.co/functions/v1/api/<route>`.
  app.use((req: Request, _res: Response, next: NextFunction) => {
    const url = req.url;
    const stripped = url === functionPrefix || url.startsWith(`${functionPrefix}/`) || url.startsWith(`${functionPrefix}?`)
      ? url.slice(functionPrefix.length) || '/'
      : url;
    req.originalUrl = `/functions/v1${functionPrefix}${stripped.startsWith('/') ? '' : '/'}${stripped}`;
    req.url = stripped.startsWith('/') ? stripped : `/${stripped}`;
    req.headers.host = publicBase.host;
    Object.defineProperty(req, 'protocol', { value: publicProtocol, configurable: true });
    next();
  });

  app.use(trackRequests);
  app.use(imageEngineGate);

  const requestContext = new RequestContextMiddleware();
  app.use(requestContext.use.bind(requestContext));
  app.use(helmet());
  app.use(compression({ level: 6, threshold: 1024 }));

  // Behind Supabase's gateway every connection comes from the gateway; the
  // client is in X-Forwarded-For. Without this, every user shares one
  // rate-limit bucket.
  const trustProxy = process.env.TRUST_PROXY ?? 'true';
  if (trustProxy !== 'false') {
    const value = /^\d+$/.test(trustProxy) ? Number(trustProxy) : trustProxy === 'true' ? true : trustProxy;
    app.getHttpAdapter().getInstance().set('trust proxy', value);
  }

  const origins = process.env.CORS_ORIGINS ?? '*';
  app.enableCors({
    origin: origins === '*' ? true : origins.split(',').map((o) => o.trim()),
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );
  app.useGlobalFilters(new AllExceptionsFilter());

  return app;
}
