import { Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MediaVisibility } from '@prisma/client';
import { MediaStorageDriver } from '../../../../backend/src/modules/media/storage/media-storage.driver';
import { MEDIA_PRIVATE_BUCKET, MEDIA_PUBLIC_BUCKET } from '../runtime/env';
import { SupabaseHttp, SupabaseHttpError } from '../supabase/supabase-http';

/** The key shape `MediaService` generates — the same guard `LocalDiskDriver` applies. */
const SAFE_KEY = /^[0-9]{4}\/[0-9]{2}\/[0-9a-f-]{36}(@[0-9]{2,4})?\.[a-z0-9]{2,4}$/;

const CONTENT_TYPES: Record<string, string> = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  gif: 'image/gif',
  heic: 'image/heic',
  avif: 'image/avif',
  mp4: 'video/mp4',
  mov: 'video/quicktime',
  webm: 'video/webm',
  m4a: 'audio/mp4',
  aac: 'audio/aac',
  mp3: 'audio/mpeg',
  ogg: 'audio/ogg',
  opus: 'audio/ogg',
  wav: 'audio/wav',
  pdf: 'application/pdf',
};

/**
 * `MediaStorageDriver` on Supabase Storage.
 *
 * The seam `media-storage.driver.ts` drew for exactly this: `MediaService`
 * never names a driver, so swapping local disk for a bucket is this class and
 * one provider override. Visibility maps to a bucket the way it mapped to a
 * directory — a caller still cannot name its way from one to the other,
 * because the bucket is chosen here and never taken from the key.
 *
 *  - `reem-media-public`  public bucket; objects are served by Storage's CDN at
 *    the URL `publicUrl()` builds, never through the function.
 *  - `reem-media-private` private bucket with no client policies at all; its
 *    bytes are only ever read here, by `MediaController`, after the
 *    backend's own authorisation check.
 */
@Injectable()
export class SupabaseStorageDriver implements MediaStorageDriver {
  readonly name = 'supabase';

  private readonly publicBaseUrl: string;

  constructor(
    private readonly http: SupabaseHttp,
    config: ConfigService,
  ) {
    this.publicBaseUrl = (
      config.get<string>('media.publicBaseUrl') ?? `/storage/v1/object/public/${MEDIA_PUBLIC_BUCKET}`
    ).replace(/\/+$/, '');
  }

  async put(key: string, bytes: Buffer, visibility: MediaVisibility): Promise<void> {
    const response = await this.http.request(this.objectPath(key, visibility), {
      method: 'POST',
      headers: {
        'Content-Type': this.contentTypeFor(key),
        // Keys are random UUIDs; an existing object means a collision or a
        // replay, and overwriting bytes other rows point at is never right.
        'x-upsert': 'false',
        'cache-control': 'max-age=31536000, immutable',
      },
      body: new Uint8Array(bytes.buffer, bytes.byteOffset, bytes.byteLength) as unknown as BodyInit,
      timeoutMs: 60_000,
    });
    if (!response.ok) {
      const text = await response.text().catch(() => '');
      throw new SupabaseHttpError(response.status, text, `storage put ${key}`);
    }
  }

  async read(key: string, visibility: MediaVisibility): Promise<Buffer> {
    const response = await this.http.request(this.objectPath(key, visibility), {
      timeoutMs: 60_000,
    });
    if (response.status === 400 || response.status === 404) {
      throw new NotFoundException('MEDIA_BYTES_MISSING');
    }
    if (!response.ok) {
      const text = await response.text().catch(() => '');
      throw new SupabaseHttpError(response.status, text, `storage read ${key}`);
    }
    return Buffer.from(await response.arrayBuffer());
  }

  async remove(key: string, visibility: MediaVisibility): Promise<void> {
    this.assertSafe(key);
    // Deleting by prefix list is idempotent: an absent key is simply not in
    // the answer.
    await this.http.expectOk(`/storage/v1/object/${this.bucketFor(visibility)}`, {
      method: 'DELETE',
      json: { prefixes: [key] },
    });
  }

  publicUrl(key: string): string {
    this.assertSafe(key);
    return `${this.publicBaseUrl}/${key}`;
  }

  private objectPath(key: string, visibility: MediaVisibility): string {
    this.assertSafe(key);
    return `/storage/v1/object/${this.bucketFor(visibility)}/${key}`;
  }

  private bucketFor(visibility: MediaVisibility): string {
    return visibility === MediaVisibility.PUBLIC ? MEDIA_PUBLIC_BUCKET : MEDIA_PRIVATE_BUCKET;
  }

  private contentTypeFor(key: string): string {
    const extension = key.slice(key.lastIndexOf('.') + 1).toLowerCase();
    return CONTENT_TYPES[extension] ?? 'application/octet-stream';
  }

  private assertSafe(key: string) {
    if (!SAFE_KEY.test(key)) {
      throw new Error(`Refusing a media key outside the generated shape: ${key}`);
    }
  }
}
