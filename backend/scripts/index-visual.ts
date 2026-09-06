/**
 * Runs one Reem Visual Shopping indexing pass on demand.
 *
 * The hourly sweep in `ProductIndexerService` is off by default
 * (`VISUAL_SEARCH_INDEXER_ENABLED`), which is right for a laptop and wrong for
 * the first time anybody wants to try the feature. This is the manual door:
 *
 *   npx ts-node scripts/index-visual.ts [batchSize]
 *
 * It describes product photographs that have no vector under the current
 * embedder, exactly as the scheduled pass would, and prints what it did. Safe
 * to re-run — an unchanged photograph is recognised by its checksum and
 * skipped.
 */
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import configuration from '../src/config/configuration';
import { CacheService } from '../src/common/cache/cache.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { EmbeddingService } from '../src/modules/visual-search/embedding/embedding.service';
import { PerceptualVisualEmbedder } from '../src/modules/visual-search/embedding/perceptual-embedder';
import { ProductIndexerService } from '../src/modules/visual-search/embedding/product-indexer.service';
import { ImageProcessingService } from '../src/modules/visual-search/processing/image-processing.service';
import { CatalogImageService } from '../src/modules/visual-search/processing/catalog-image.service';
import { PostgresVectorIndex } from '../src/modules/visual-search/vector/postgres-vector-index';
import { MediaService } from '../src/modules/media/media.service';
import { LocalDiskDriver } from '../src/modules/media/storage/local-disk.driver';
import { ImageDerivativesService } from '../src/modules/media/image-derivatives';

async function main(): Promise<void> {
  const batch = Number.parseInt(process.argv[2] ?? '', 10);

  const prisma = new PrismaClient() as unknown as PrismaService;
  const config = new ConfigService(configuration());

  const storage = new LocalDiskDriver(config);
  const media = new MediaService(
    prisma,
    config,
    storage,
    new ImageDerivativesService(),
  );

  const processing = new ImageProcessingService(config);
  const embedder = new PerceptualVisualEmbedder();
  const embeddings = new EmbeddingService(embedder, processing, new CacheService());
  const index = new PostgresVectorIndex(prisma, embedder);

  const indexer = new ProductIndexerService(
    prisma,
    config,
    embeddings,
    processing,
    new CatalogImageService(media, config),
    index,
  );

  const summary = await indexer.sweep(
    Number.isFinite(batch) ? { limit: batch } : {},
  );
  const coverage = await indexer.coverage();

  console.log(JSON.stringify({ embedder: embedder.name, summary, coverage }, null, 2));
  await (prisma as unknown as PrismaClient).$disconnect();
}

void main();
