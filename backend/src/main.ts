import 'reflect-metadata';
import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import compression from 'compression';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { SingleQueryValuePipe } from './common/pipes/single-query-value.pipe';
import type { NextFunction, Request, Response } from 'express';
import { LocalDiskDriver } from './modules/media/storage/local-disk.driver';
import { RequestContextMiddleware } from './common/observability/request-context.middleware';
import { StructuredLogger } from './common/observability/structured-logger';

async function bootstrap() {
  // `rawBody` is required by the WhatsApp webhook: Meta signs the exact bytes
  // it sent, so a signature verified against re-serialised JSON would fail on
  // any key-order or whitespace difference.
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    rawBody: true,
    // One JSON object per line in production, with the request id attached, so
    // a support agent can search for the string the customer read off her
    // screen. Development keeps the readable format — see `StructuredLogger`.
    logger: new StructuredLogger('Reem'),
  });
  const config = app.get(ConfigService);

  // First in the chain, before helmet and before every guard: a request that
  // is refused by authentication still needs a name, or the one failure a
  // customer reports is the one nothing can be found for.
  app.use(new RequestContextMiddleware().use.bind(new RequestContextMiddleware()));

  // Security headers.
  app.use(helmet());

  /**
   * Compress every response.
   *
   * This API answered uncompressed. The home screen is 224 KB of Arabic JSON
   * and gzips to 37 KB — an 84% reduction, because the payload is repetitive
   * key names and UTF-8 Arabic, which is exactly what DEFLATE is good at. On
   * the connections this platform actually serves, that is the difference
   * between a home screen that arrives and one a woman gives up on; it was
   * also, measured against everything else in the performance audit, the
   * single largest win available and the one that required no change to any
   * response shape.
   *
   * Two notes on the settings:
   *
   *  - Level 6 is zlib's default and the right trade. Level 9 costs roughly
   *    twice the CPU for about 1% more compression on JSON.
   *  - Below a kilobyte, compression makes responses *larger* once the gzip
   *    header is counted, so the threshold leaves small ones alone.
   *
   * BREACH does not apply here: the attack extracts a secret that a response
   * body reflects back beside attacker-controlled input, and this API carries
   * its credential in a header — there are no cookies and no CSRF tokens in
   * any body. `compression` also skips content types that are already
   * compressed, so the media mount below is unaffected.
   */
  app.use(
    compression({
      level: 6,
      threshold: 1024,
    }),
  );

  /**
   * Rate limiting is scoped by client IP. Behind a reverse proxy every request
   * appears to come from the proxy, so without this the whole platform shares
   * a single throttle bucket: one noisy client exhausts the limit for
   * everybody, and per-IP brute-force protection on the auth routes stops
   * distinguishing between attacker and users. Off by default, because
   * trusting `X-Forwarded-For` when no proxy is in front lets a caller forge
   * their own address and escape the limiter entirely.
   */
  const trustProxy = config.get<string>('trustProxy') ?? 'false';
  if (trustProxy !== 'false') {
    const value = /^\d+$/.test(trustProxy) ? Number(trustProxy) : trustProxy;
    app.getHttpAdapter().getInstance().set('trust proxy', value);
    Logger.log(`Trusting proxy: ${trustProxy}`, 'Bootstrap');
  }

  // CORS.
  const origins = config.get<string>('cors.origins') ?? '*';
  app.enableCors({
    origin: origins === '*' ? true : origins.split(',').map((o) => o.trim()),
    credentials: true,
  });

  // Optional global prefix (empty by default to match the Flutter client).
  const prefix = config.get<string>('apiPrefix');
  if (prefix) app.setGlobalPrefix(prefix);

  /**
   * Public uploads, served off disk.
   *
   * Only the `public` root is mounted — private assets live in a sibling
   * directory that nothing static can reach, and are streamed by
   * `MediaController` after an authorisation check. That separation is the
   * point: a mistake in this mount can expose product photographs, which are
   * already public, and cannot expose a seller's identity documents.
   *
   * Deliberately mounted outside the global API prefix. These URLs are stored
   * in rows and rendered by clients for years; moving `API_PREFIX` should not
   * break every image the platform has ever saved.
   */
  if (config.get<string>('media.driver') === 'local') {
    const driver = app.get(LocalDiskDriver);
    const mediaRoot = driver.publicRoot;
    app.useStaticAssets(mediaRoot, {
      prefix: config.get<string>('media.publicBaseUrl') ?? '/media/files',
      index: false,
      redirect: false,
      dotfiles: 'deny',
      // Filenames are random and content-addressed in practice, so a stored
      // URL never points at different bytes later.
      maxAge: '365d',
      immutable: true,
      setHeaders: (res) => {
        // The type was decided by sniffing the bytes at upload time; forbid
        // the browser from reconsidering it here.
        res.setHeader('X-Content-Type-Options', 'nosniff');
        // helmet defaults CORP to `same-origin`, which is right for the API
        // and wrong for images a web client is meant to embed.
        res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
      },
    });
    /**
     * A request for a resized copy that does not exist falls back to the
     * original.
     *
     * The client asks for `<uuid>@480.webp` by convention, from nothing but a
     * URL — it has no way to know which widths were generated. Without this,
     * every image uploaded before derivatives existed, and every upload
     * already smaller than the variant, would 404 and render as a broken
     * frame. Registered *after* the static mount, so it costs nothing on a
     * hit and only runs when the file was genuinely absent.
     */
    const mediaPrefix =
      config.get<string>('media.publicBaseUrl') ?? '/media/files';
    app.use(mediaPrefix, (req: Request, res: Response, next: NextFunction) => {
      /**
       * Resolution belongs to the driver, which holds the one definition of
       * what a key this platform generated looks like. Joining `req.path`
       * onto the public root here instead would trust a string Express
       * neither decodes nor normalises: `../private/<uuid>@480.webp` would
       * collapse into the sibling bucket and stream a woman's closet
       * photograph or a seller's identity document to anyone who asked.
       */
      const original = driver.resolvePublicVariantFallback(req.path);
      if (!original) return next();

      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
      return res.sendFile(original);
    });

    Logger.log(`Serving public media from ${mediaRoot}`, 'Bootstrap');
  }

  // Validation: refuse repeated single-value query keys, strip unknown props,
  // reject extras, coerce types.
  app.useGlobalPipes(
    new SingleQueryValuePipe(),
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // Uniform error envelope.
  app.useGlobalFilters(new AllExceptionsFilter());

  app.enableShutdownHooks();

  const port = config.get<number>('port') ?? 3000;
  const host = config.get<string>('host') ?? '0.0.0.0';

  /**
   * Keep-alive longer than the proxy's.
   *
   * Node closes an idle keep-alive connection after 5 s by default, while the
   * load balancer in front of a hosted service keeps its side open for about a
   * minute. When the two disagree the proxy reuses a connection Node has just
   * closed and the client gets a sporadic 502 — rare, unreproducible, and on
   * checkout as likely as anywhere. `headersTimeout` must exceed it or Node
   * enforces the shorter one.
   */
  const server = app.getHttpServer() as import('http').Server;
  server.keepAliveTimeout = 75_000;
  server.headersTimeout = 76_000;

  if (config.get<string>('nodeEnv') === 'production' && trustProxy === 'false') {
    // Not refused: a server exposed directly is legitimate. But every hosted
    // platform puts a proxy in front, and then rate limiting sees one address
    // for the whole country.
    Logger.warn(
      'TRUST_PROXY is false in production. Behind a hosting proxy, rate limiting ' +
        'will see the proxy address for every client — set TRUST_PROXY=1.',
      'Bootstrap',
    );
  }

  await app.listen(port, host);

  const path = prefix ? `/${prefix}` : '';
  Logger.log(`Reem API listening on ${host}:${port}${path}`, 'Bootstrap');
  Logger.log(
    `Physical devices should use http://<your-computer-LAN-IP>:${port}${path}`,
    'Bootstrap',
  );
}

bootstrap();
