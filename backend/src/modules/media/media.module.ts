import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';
import { ImageDerivativesService } from './image-derivatives';
import { MediaSweeperService } from './media-sweeper.service';
import { LocalDiskDriver } from './storage/local-disk.driver';
import { MEDIA_STORAGE_DRIVER } from './storage/media-storage.driver';
import { SupabaseStorageDriver } from './storage/supabase-storage.driver';

/**
 * Global because almost every write path eventually claims an upload —
 * products, stories, avatars, seller verification. Threading an import of this
 * module through each of their modules would be six edits that say nothing.
 *
 * `MEDIA_DRIVER` picks where bytes go: `local` (the API host's disk) or
 * `supabase` (Supabase Storage, reached only from this process with the
 * project's secret key). Adding another store means writing its driver and a
 * line in the factory's switch, and nothing else: `MediaService` never names a
 * driver, and every asset row records which one wrote it.
 */
@Global()
@Module({
  controllers: [MediaController],
  providers: [
    MediaService,
    MediaSweeperService,
    ImageDerivativesService,
    LocalDiskDriver,
    SupabaseStorageDriver,
    {
      provide: MEDIA_STORAGE_DRIVER,
      useFactory: (
        config: ConfigService,
        local: LocalDiskDriver,
        supabase: SupabaseStorageDriver,
      ) => (config.get<string>('media.driver') === 'supabase' ? supabase : local),
      inject: [ConfigService, LocalDiskDriver, SupabaseStorageDriver],
    },
  ],
  exports: [MediaService, LocalDiskDriver],
})
export class MediaModule {}
