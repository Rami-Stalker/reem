import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    super({
      log:
        process.env.NODE_ENV === 'production'
          ? ['error']
          : ['error', 'warn'],
    });
  }

  // Fail fast: if the database is unreachable at boot, surface it clearly
  // rather than letting the first request 500. Nest aborts startup on throw.
  async onModuleInit(): Promise<void> {
    try {
      await this.$connect();
      this.logger.log('Connected to PostgreSQL');
    } catch (error) {
      this.logger.error(
        'Failed to connect to PostgreSQL — check DATABASE_URL and that the server is reachable.',
        error instanceof Error ? error.stack : String(error),
      );
      throw error;
    }
  }

  // Paired with app.enableShutdownHooks() in main.ts for graceful shutdown:
  // drains the connection pool before the process exits.
  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
    this.logger.log('Disconnected from PostgreSQL');
  }
}
