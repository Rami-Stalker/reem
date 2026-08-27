import { MediaVisibility } from '@prisma/client';

/** DI token for the storage driver the platform is currently writing to. */
export const MEDIA_STORAGE_DRIVER = Symbol('MEDIA_STORAGE_DRIVER');

/**
 * Where bytes live.
 *
 * The platform stores uploads on the API host's disk today. That is the right
 * answer for a closed beta in Syria — no bucket to pay for, no egress, and it
 * keeps working when the machine cannot reach anything abroad. It is the wrong
 * answer for two API instances, so the seam is drawn here rather than later:
 * `MediaService` never touches `fs`, and adding S3/MinIO means adding one
 * class and one line in `media.module.ts` — the same shape `PaymentProvider`
 * already uses for payment rails.
 *
 * `visibility` is a parameter on every call rather than a segment the caller
 * bakes into `key`. A caller cannot then name its way out of the private tree:
 * the driver owns the mapping from visibility to root, and a photograph of a
 * national ID cannot land in a publicly-served directory because someone
 * built a string wrong.
 */
export interface MediaStorageDriver {
  /** Recorded on every asset row, so bytes stay readable after the platform moves. */
  readonly name: string;

  put(key: string, bytes: Buffer, visibility: MediaVisibility): Promise<void>;

  read(key: string, visibility: MediaVisibility): Promise<Buffer>;

  /** Idempotent: deleting an already-absent key is not an error. */
  remove(key: string, visibility: MediaVisibility): Promise<void>;

  /**
   * The URL a client should use for a PUBLIC asset. Private assets have no
   * such URL by construction — they are streamed through an authorised
   * handler — so this throws rather than returning something guessable.
   */
  publicUrl(key: string): string;
}
