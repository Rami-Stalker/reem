import 'dotenv/config';

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL is missing in .env');
}

if (!process.env.JWT_ACCESS_SECRET) {
  throw new Error('JWT_ACCESS_SECRET is missing in .env');
}

if (!process.env.JWT_REFRESH_SECRET) {
  throw new Error('JWT_REFRESH_SECRET is missing in .env');
}

import express from 'express';
import http from 'http';

import { logger } from './lib/logger.js';
import { prisma } from './lib/prisma.js';

const app = express();
const server = http.createServer(app);

const port = process.env.PORT || 3000;
const prefix = process.env.API_PREFIX;
const nodeEnv = process.env.NODE_ENV;

async function main() {
  logger.info('Starting server');

  await prisma.$connect();
  logger.info('Database connected');

  server.listen(port, () => {

    logger.info(
      { port, prefix, env: nodeEnv },
      'Reem API server started',
    );
  });
}

main().catch((err) => {
  logger.fatal({ err }, 'Failed to start server');
  process.exit(1);
});

process.on('SIGINT', async () => {
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await prisma.$disconnect();
  process.exit(0);
});