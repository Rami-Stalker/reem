import { Global, Module } from '@nestjs/common';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';
import { ImageDerivativesService } from './image-derivatives';
import { MediaSweeperService } from './media-sweeper.service';
import { LocalDiskDriver } from './storage/local-disk.driver';
import { MEDIA_STORAGE_DRIVER } from './storage/media-storage.driver';

/**
 * Global because almost every write path eventually claims an upload —
 * products, stories, avatars, seller verification. Threading an import of this
 * module through each of their modules would be six edits that say nothing.
 *
 * Adding object storage means writing an `S3Driver`, adding it to the
 * factory's switch, and nothing else: `MediaService` never names a driver, and
 * every asset row records which one wrote it so files predating the move stay
 * readable.
 */
@Global()
@Module({
  controllers: [MediaController],
  providers: [
    MediaService,
    MediaSweeperService,
    ImageDerivativesService,
    LocalDiskDriver,
    {
      provide: MEDIA_STORAGE_DRIVER,
      useFactory: (local: LocalDiskDriver) => local,
      inject: [LocalDiskDriver],
    },
  ],
  exports: [MediaService, LocalDiskDriver],
})
export class MediaModule {}
