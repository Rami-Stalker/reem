import 'reflect-metadata';
import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);

  // Security headers.
  app.use(helmet());

  // CORS.
  const origins = config.get<string>('cors.origins') ?? '*';
  app.enableCors({
    origin: origins === '*' ? true : origins.split(',').map((o) => o.trim()),
    credentials: true,
  });

  // Optional global prefix (empty by default to match the Flutter client).
  const prefix = config.get<string>('apiPrefix');
  if (prefix) app.setGlobalPrefix(prefix);

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
  await app.listen(port);

  Logger.log(
    `🚀 Reem API running on http://localhost:${port}${prefix ? '/' + prefix : ''}`,
    'Bootstrap',
  );
}

bootstrap();
