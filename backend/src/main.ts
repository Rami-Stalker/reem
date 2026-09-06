import 'reflect-metadata';
import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import type { NextFunction, Request, Response } from 'express';
import { LocalDiskDriver } from './modules/media/storage/local-disk.driver';

async function bootstrap() {
  // `rawBody` is required by the WhatsApp webhook: Meta signs the exact bytes
  // it sent, so a signature verified against re-serialised JSON would fail on
  // any key-order or whitespace difference.
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    rawBody: true,
  });
  const config = app.get(ConfigService);

  // Security headers.
  app.use(helmet());

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

  // Validation: strip unknown props, reject extras, coerce types.
  app.useGlobalPipes(
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
  await app.listen(port, host);

  const path = prefix ? `/${prefix}` : '';
  Logger.log(`Reem API listening on ${host}:${port}${path}`, 'Bootstrap');
  Logger.log(
    `Physical devices should use http://<your-computer-LAN-IP>:${port}${path}`,
    'Bootstrap',
  );
}

bootstrap();
