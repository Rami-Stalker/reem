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
      /**
       * Interactive transactions (checkout, ledger postings, returns) are a
       * sequence of round trips, so their budget depends on where this
       * process runs relative to the database. Prisma's defaults — 5 s to run,
       * 2 s to get a connection — are right for an API in the database's own
       * region. An instance far from it (a developer machine against the
       * Supabase database in Frankfurt) spends most of that on the network and
       * fails checkout with "Transaction already closed". Configurable rather
       * than raised for everyone: a long timeout also means locks held longer.
       */
      transactionOptions: {
        timeout: positiveInt(process.env.DATABASE_TRANSACTION_TIMEOUT_MS, 5_000),
        maxWait: positiveInt(process.env.DATABASE_TRANSACTION_MAX_WAIT_MS, 2_000),
      },
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

function positiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(value ?? '', 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
