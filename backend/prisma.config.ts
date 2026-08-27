import path from 'node:path';
// A Prisma config file switches off the CLI's implicit .env loading, so the
// environment has to be loaded explicitly before `env("DATABASE_URL")` resolves.
import 'dotenv/config';
import { defineConfig } from 'prisma/config';

/**
 * Prisma CLI configuration.
 *
 * Replaces the `package.json#prisma` block, which Prisma 7 removes and which
 * the CLI warned about on every command.
 */
export default defineConfig({
  schema: path.join('prisma', 'schema.prisma'),
  migrations: {
    // Used by `prisma migrate reset` and `prisma db seed`.
    seed: 'ts-node prisma/seed.ts',
  },
});
