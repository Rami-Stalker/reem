import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MediaVisibility } from '@prisma/client';
import { existsSync, promises as fs } from 'node:fs';
import { dirname, join, resolve, sep } from 'node:path';
import { MediaStorageDriver } from './media-storage.driver';

/**
 * A generated key and nothing else: two path segments of digits, a uuid, an
 * optional `@width` for a resized copy, and a short extension. Deliberately
 * stricter than "no `..`" — an allow-list cannot be talked around by
 * URL-encoding, and every key this platform generates looks like
 * `2026/08/<uuid>.jpg` or `2026/08/<uuid>@480.webp`.
 */
const SAFE_KEY =
  /^[0-9]{4}\/[0-9]{2}\/[0-9a-f-]{36}(@[0-9]{2,4})?\.[a-z0-9]{2,4}$/;

@Injectable()
export class LocalDiskDriver implements MediaStorageDriver {
  readonly name = 'local';

  private readonly logger = new Logger(LocalDiskDriver.name);
  private readonly root: string;
  private readonly publicBaseUrl: string;

  constructor(private readonly config: ConfigService) {
    this.root = resolve(
      this.config.get<string>('media.localRoot') ?? 'storage/media',
    );
    this.publicBaseUrl = (
      this.config.get<string>('media.publicBaseUrl') ?? '/media/files'
    ).replace(/\/+$/, '');
  }

  async put(
    key: string,
    bytes: Buffer,
    visibility: MediaVisibility,
  ): Promise<void> {
    const path = this.pathFor(key, visibility);
    await fs.mkdir(dirname(path), { recursive: true });
    // `wx` — never overwrite. Keys are random so a collision means something
    // is wrong upstream, and silently replacing another woman's photograph is
    // the worst possible way to find that out.
    await fs.writeFile(path, bytes, { flag: 'wx' });
  }

  async read(key: string, visibility: MediaVisibility): Promise<Buffer> {
    try {
      return await fs.readFile(this.pathFor(key, visibility));
    } catch {
      // The row exists but the bytes do not — a half-restored backup, a
      // hand-deleted file. A 404 is honest; a 500 sends someone hunting for a
      // bug in the code.
      throw new NotFoundException('MEDIA_BYTES_MISSING');
    }
  }

  async remove(key: string, visibility: MediaVisibility): Promise<void> {
    try {
      await fs.rm(this.pathFor(key, visibility));
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code !== 'ENOENT') {
        this.logger.warn(`Failed to remove ${key}: ${String(error)}`);
        throw error;
      }
    }
  }

  publicUrl(key: string): string {
    this.assertSafe(key);
    return `${this.publicBaseUrl}/${key}`;
  }

  /** The directory a reverse proxy may serve directly. Nothing private is under it. */
  get publicRoot(): string {
    return join(this.root, 'public');
  }

  private pathFor(key: string, visibility: MediaVisibility): string {
    this.assertSafe(key);
    const bucket = visibility === MediaVisibility.PUBLIC ? 'public' : 'private';
    const path = resolve(join(this.root, bucket, key));

    // Belt and braces. `SAFE_KEY` already makes traversal impossible; this
    // catches the case where it is ever loosened, and costs one string compare.
    const base = resolve(join(this.root, bucket)) + sep;
    if (!path.startsWith(base)) {
      throw new Error(`Refusing to resolve media key outside its root: ${key}`);
    }
    return path;
  }

  /**
   * The original bytes behind a request for a resized variant that was never
   * generated, or `null` when the request is not asking for one — or is not
   * asking for a key this platform produced.
   *
   * This lives on the driver rather than in the middleware that wants it
   * because `SAFE_KEY` is the rule for what counts as one of our keys, and a
   * second copy of that rule elsewhere is precisely how a public mount grows
   * a path back into the private bucket.
   */
  resolvePublicVariantFallback(requestPath: string): string | null {
    const withoutVariant = requestPath.replace(/@\d+\.webp$/i, '');
    if (withoutVariant === requestPath) return null;

    const stem = withoutVariant.replace(/^\/+/, '');
    const base = resolve(join(this.root, 'public')) + sep;

    // Only the extension is unknown, so try the ones the sniffer stores.
    for (const extension of ['jpg', 'png', 'webp', 'gif']) {
      const key = `${stem}.${extension}`;
      if (!SAFE_KEY.test(key)) continue;
      const candidate = resolve(join(this.root, 'public', key));
      if (!candidate.startsWith(base)) continue;
      if (existsSync(candidate)) return candidate;
    }
    return null;
  }

  private assertSafe(key: string): void {
    if (!SAFE_KEY.test(key)) {
      throw new Error(`Unsafe media storage key: ${key}`);
    }
  }
}
