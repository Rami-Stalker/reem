import {
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MediaVisibility } from '@prisma/client';
import { MediaStorageDriver } from './media-storage.driver';

/** The key shape `MediaService` generates — the same guard `LocalDiskDriver` applies. */
const SAFE_KEY =
  /^[0-9]{4}\/[0-9]{2}\/[0-9a-f-]{36}(@[0-9]{2,4})?\.[a-z0-9]{2,4}$/;

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
 * `MediaStorageDriver` on Supabase Storage, driven by this API.
 *
 * Supabase hosts the bytes; it is not a backend the app talks to. Every call
 * here is server-to-server and authenticated with the project's secret key,
 * which lives in this process's environment and nowhere else — the app never
 * holds it, never holds a Supabase session, and never names a bucket.
 *
 * Visibility maps to a bucket the way it maps to a directory on disk, and the
 * bucket is chosen here rather than taken from the key, so a caller still
 * cannot name its way from the public tree into the private one:
 *
 *  - `reem-media-public`: public bucket. Objects are served by Storage's CDN at
 *    the absolute URL `publicUrl()` returns — product photographs are public
 *    by nature and a CDN is the right thing to serve them.
 *  - `reem-media-private`: private bucket with no client policy at all. Its
 *    bytes are only ever read here, streamed by `GET /media/:id/file` after
 *    `MediaService`'s own authorisation check.
 *
 * Rows written by the Supabase Edge Function deployment carry
 * `driver = 'supabase'` and live in these same buckets, so every file uploaded
 * before the move to a server stays readable without copying anything.
 */
@Injectable()
export class SupabaseStorageDriver implements MediaStorageDriver {
  readonly name = 'supabase';

  private readonly logger = new Logger(SupabaseStorageDriver.name);
  private readonly projectUrl: string;
  private readonly secretKey: string;
  private readonly publicBucket: string;
  private readonly privateBucket: string;
  private readonly publicBaseUrl: string;

  constructor(config: ConfigService) {
    this.projectUrl = (config.get<string>('supabase.url') ?? '').replace(
      /\/+$/,
      '',
    );
    this.secretKey = config.get<string>('supabase.secretKey') ?? '';
    this.publicBucket =
      config.get<string>('supabase.publicBucket') ?? 'reem-media-public';
    this.privateBucket =
      config.get<string>('supabase.privateBucket') ?? 'reem-media-private';
    this.publicBaseUrl = (
      config.get<string>('media.publicBaseUrl') ??
      `/storage/v1/object/public/${this.publicBucket}`
    ).replace(/\/+$/, '');
  }

  async put(
    key: string,
    bytes: Buffer,
    visibility: MediaVisibility,
  ): Promise<void> {
    const response = await this.request(this.objectPath(key, visibility), {
      method: 'POST',
      headers: {
        'Content-Type': this.contentTypeFor(key),
        // Keys are random UUIDs; an existing object means a collision or a
        // replay, and overwriting bytes other rows point at is never right.
        'x-upsert': 'false',
        'cache-control': 'max-age=31536000, immutable',
      },
      body: bytes,
      timeoutMs: 120_000,
    });
    if (!response.ok) {
      throw await this.failure(response, `put ${key}`);
    }
  }

  async read(key: string, visibility: MediaVisibility): Promise<Buffer> {
    const response = await this.request(this.objectPath(key, visibility), {
      timeoutMs: 120_000,
    });
    // Storage answers 400 for an absent object as often as 404.
    if (response.status === 400 || response.status === 404) {
      throw new NotFoundException('MEDIA_BYTES_MISSING');
    }
    if (!response.ok) {
      throw await this.failure(response, `read ${key}`);
    }
    return Buffer.from(await response.arrayBuffer());
  }

  async remove(key: string, visibility: MediaVisibility): Promise<void> {
    this.assertSafe(key);
    // Deleting by prefix list is idempotent: an absent key is simply not in
    // the answer.
    const response = await this.request(
      `/storage/v1/object/${this.bucketFor(visibility)}`,
      {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prefixes: [key] }),
      },
    );
    if (!response.ok) {
      throw await this.failure(response, `remove ${key}`);
    }
  }

  /** Absolute: public objects are served by Storage, not by this API. */
  publicUrl(key: string): string {
    this.assertSafe(key);
    return `${this.projectUrl}${this.publicBaseUrl}/${key}`;
  }

  private async request(
    path: string,
    options: {
      method?: string;
      headers?: Record<string, string>;
      body?: Buffer | string;
      timeoutMs?: number;
    } = {},
  ): Promise<Response> {
    if (!this.projectUrl || !this.secretKey) {
      // Env validation refuses to boot without both; this is the guard for a
      // test module or script that built the driver by hand.
      throw new ServiceUnavailableException('MEDIA_STORAGE_NOT_CONFIGURED');
    }
    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(),
      options.timeoutMs ?? 15_000,
    );
    try {
      return await fetch(`${this.projectUrl}${path}`, {
        method: options.method ?? 'GET',
        headers: {
          apikey: this.secretKey,
          Authorization: `Bearer ${this.secretKey}`,
          ...options.headers,
        },
        body: options.body as BodyInit | undefined,
        signal: controller.signal,
      });
    } catch (error) {
      this.logger.error(`Supabase Storage unreachable for ${path}: ${String(error)}`);
      throw new ServiceUnavailableException('MEDIA_STORAGE_UNAVAILABLE');
    } finally {
      clearTimeout(timer);
    }
  }

  private async failure(response: Response, action: string): Promise<Error> {
    const text = await response.text().catch(() => '');
    // The body can carry the bucket name and the key; it goes to the log, and
    // the client gets a code.
    this.logger.error(
      `Supabase Storage ${action} answered ${response.status}: ${text.slice(0, 300)}`,
    );
    return new ServiceUnavailableException('MEDIA_STORAGE_FAILED');
  }

  private objectPath(key: string, visibility: MediaVisibility): string {
    this.assertSafe(key);
    return `/storage/v1/object/${this.bucketFor(visibility)}/${key}`;
  }

  private bucketFor(visibility: MediaVisibility): string {
    return visibility === MediaVisibility.PUBLIC
      ? this.publicBucket
      : this.privateBucket;
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
