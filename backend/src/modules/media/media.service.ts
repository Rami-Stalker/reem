import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  MediaAsset,
  MediaAssetStatus,
  MediaType,
  MediaVisibility,
} from '@prisma/client';
import { createHash, randomUUID } from 'node:crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { AppPermission } from '../../common/permissions';
import { resolvePermissions } from '../../common/authorization/permission-resolver';
import {
  MEDIA_STORAGE_DRIVER,
  MediaStorageDriver,
} from './storage/media-storage.driver';
import { sniffMedia } from './media-sniffer';
import { ImageDerivativesService } from './image-derivatives';

export interface UploadInput {
  buffer: Buffer;
  originalName?: string;
  visibility: MediaVisibility;
  purpose?: string;

  /// What may be uploaded here. Derived from the purpose by the controller —
  /// see `acceptedKinds`. Absent means images only, which is the safe reading
  /// of a caller that did not say.
  allowedKinds?: MediaType[];
}

@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    @Inject(MEDIA_STORAGE_DRIVER)
    private readonly storage: MediaStorageDriver,
    private readonly derivatives: ImageDerivativesService,
  ) {}

  // ── Upload ────────────────────────────────────────────────────────────────

  async upload(ownerId: string, input: UploadInput): Promise<MediaAsset> {
    const { buffer } = input;
    if (!buffer?.length) {
      throw new BadRequestException('EMPTY_UPLOAD');
    }

    // Sniff before anything else. Every decision below — the size ceiling that
    // applies, the extension written to disk, the Content-Type served back —
    // depends on what the bytes are, and the client's account of that is not
    // evidence.
    const sniffed = sniffMedia(buffer);
    if (!sniffed) {
      throw new UnsupportedMediaTypeException('UNSUPPORTED_MEDIA_TYPE');
    }

    // A PDF is a real answer for a commercial register, a voice note is one
    // for a conversation, and either is a broken tile where a product
    // photograph belongs. The purpose decides, and the purpose is the server's
    // reading of it — not a flag the client set.
    const allowed = input.allowedKinds ?? [MediaType.image];
    if (!allowed.includes(sniffed.kind)) {
      throw new UnsupportedMediaTypeException(
        `${sniffed.kind.toUpperCase()}_NOT_ALLOWED_HERE`,
      );
    }

    const limit = {
      [MediaType.image]: this.config.get<number>('media.maxImageBytes')!,
      [MediaType.video]: this.config.get<number>('media.maxVideoBytes')!,
      [MediaType.document]: this.config.get<number>('media.maxDocumentBytes')!,
      [MediaType.audio]: this.config.get<number>('media.maxAudioBytes')!,
    }[sniffed.kind];
    if (buffer.length > limit) {
      throw new PayloadTooLargeException('MEDIA_TOO_LARGE');
    }

    await this.assertUnderDailyQuota(ownerId);

    const checksum = createHash('sha256').update(buffer).digest('hex');

    // Re-picking the same photograph is ordinary behaviour — she taps the
    // wrong thumbnail, backs out, taps it again. Returning the existing asset
    // costs one indexed lookup and saves a duplicate file. Scoped to the same
    // owner *and* the same visibility: deduplicating across that boundary
    // would hand back a private document's row to a public request.
    const existing = await this.prisma.mediaAsset.findFirst({
      where: { ownerId, checksum, visibility: input.visibility },
      orderBy: { createdAt: 'desc' },
    });
    if (existing) return existing;

    const now = new Date();
    const key = [
      String(now.getUTCFullYear()),
      String(now.getUTCMonth() + 1).padStart(2, '0'),
      `${randomUUID()}.${sniffed.extension}`,
    ].join('/');

    await this.storage.put(key, buffer, input.visibility);

    // Resized copies and a blur hash, for images only. Derived after the
    // original is safely stored: if this half fails the upload still succeeds
    // and the client falls back to the full-size file, which is exactly how it
    // behaved before any of this existed.
    const derived =
      sniffed.kind === MediaType.image
        ? await this.derivatives.derive(buffer)
        : { variants: [], blurHash: null };

    const storedWidths: number[] = [];
    for (const variant of derived.variants) {
      const variantKey = variantKeyFor(key, variant.width);
      try {
        await this.storage.put(variantKey, variant.bytes, input.visibility);
        storedWidths.push(variant.width);
      } catch (error) {
        this.logger.warn(
          `Could not store the ${variant.width}px copy of ${key}: ${String(error)}`,
        );
      }
    }

    try {
      return await this.prisma.mediaAsset.create({
        data: {
          ownerId,
          driver: this.storage.name,
          storageKey: key,
          visibility: input.visibility,
          status: MediaAssetStatus.PENDING,
          mimeType: sniffed.mimeType,
          kind: sniffed.kind,
          byteSize: buffer.length,
          width: sniffed.width ?? null,
          height: sniffed.height ?? null,
          checksum,
          variants: storedWidths,
          blurHash: derived.blurHash,
          originalName: input.originalName?.slice(0, 200) ?? null,
          purpose: input.purpose ?? null,
        },
      });
    } catch (error) {
      // The bytes are already on disk and no row will ever point at them, so
      // the sweeper cannot find them either — it works from rows. Clean up
      // here or leak the file permanently.
      await this.storage.remove(key, input.visibility).catch(() => undefined);
      for (const width of storedWidths) {
        await this.storage
          .remove(variantKeyFor(key, width), input.visibility)
          .catch(() => undefined);
      }
      throw error;
    }
  }

  // ── Reading ───────────────────────────────────────────────────────────────

  /**
   * Bytes for a private asset, with the access decision attached.
   *
   * Private today means one thing: seller verification documents, which
   * include a photograph of a national ID. Her own account may fetch them, and
   * so may staff who review verifications — nobody else, regardless of how
   * senior. The blanket admin exemption in `assertCanManage` is deliberately
   * not reused here.
   */
  async readPrivate(id: string, actor: AuthUser) {
    const asset = await this.prisma.mediaAsset.findUnique({ where: { id } });
    if (!asset) throw new NotFoundException('MEDIA_NOT_FOUND');

    if (asset.visibility === MediaVisibility.PUBLIC) {
      // Nothing secret, but route it through the public URL so the proxy and
      // the cache headers apply instead of streaming it through Node.
      throw new BadRequestException('MEDIA_IS_PUBLIC');
    }

    if (!(await this.mayRead(asset, actor))) {
      throw new ForbiddenException('MEDIA_FORBIDDEN');
    }

    const bytes = await this.storage.read(asset.storageKey, asset.visibility);
    return { asset, bytes };
  }

  /**
   * Who, besides the uploader, may open a private asset.
   *
   * One rule per purpose, deliberately — there is no general "staff may read
   * private media" clause, because the two private purposes are answering
   * different questions. A verification document is reviewed by the people
   * whose job that is. A photograph sent into a conversation is read by the
   * people in that conversation, and by nobody else at all: not support, not
   * an administrator. Adding a purpose without adding a rule here fails
   * closed.
   */
  private async mayRead(asset: MediaAsset, actor: AuthUser): Promise<boolean> {
    if (asset.ownerId === actor.id) return true;

    switch (asset.purpose) {
      case 'verification': {
        /**
         * Resolved from the database, not from `actor.permissions`.
         *
         * That field is the claim minted into the access token, so it answers
         * "what did this reviewer hold when she signed in" — and the bytes on
         * the other side of this check are national ID cards and commercial
         * registers. A reviewer whose `UserRoleAssignment` lapsed, or whose
         * permission was pulled precisely because she should no longer be
         * reading them, kept reading them until her token expired. This is the
         * same fix `AuthorizationService.permissionsFor` already made for
         * every permission-gated route; this call site was missed because it
         * decides in a service rather than in the guard.
         */
        const permissions = await resolvePermissions(
          this.prisma,
          actor.id,
          actor.role,
        );
        return permissions.has(AppPermission.sellerVerificationReview);
      }
      case 'chat':
        return this.isInAChatWith(asset.id, actor.id);
      default:
        return false;
    }
  }

  /**
   * Is this asset attached to a message in a conversation the actor is part of?
   *
   * Answered from `MessageAttachment.mediaAssetId`, which is why that column
   * exists: the alternative is a suffix match on the URL across every
   * attachment ever sent, because the origin a URL was issued under is not the
   * origin it is read back under.
   */
  private async isInAChatWith(
    assetId: string,
    userId: string,
  ): Promise<boolean> {
    const count = await this.prisma.messageAttachment.count({
      where: {
        mediaAssetId: assetId,
        message: { chat: { participants: { some: { userId } } } },
      },
    });
    return count > 0;
  }

  /**
   * The blur hash for each URL that is one of ours, keyed by URL.
   *
   * For callers that denormalise it onto their own row — a product's media, so
   * a listing page of twenty cards does not need twenty joins to draw a
   * placeholder. Scoped to the owner, like every other resolution here: a URL
   * she did not upload tells her nothing about it.
   */
  async blurHashesFor(
    urls: readonly string[],
    ownerId: string,
  ): Promise<Map<string, string | null>> {
    const hashes = new Map<string, string | null>();
    if (!urls.length) return hashes;

    const keys = new Map<string, string>();
    const ids = new Map<string, string>();
    for (const url of urls) {
      const id = this.idFromPrivateUrl(url);
      if (id) {
        ids.set(id, url);
        continue;
      }
      const key = this.keyFromUrl(url);
      if (key) keys.set(key, url);
    }
    if (!keys.size && !ids.size) return hashes;

    const assets = await this.prisma.mediaAsset.findMany({
      where: {
        ownerId,
        OR: [
          ...(keys.size ? [{ storageKey: { in: [...keys.keys()] } }] : []),
          ...(ids.size ? [{ id: { in: [...ids.keys()] } }] : []),
        ],
      },
      select: { id: true, storageKey: true, blurHash: true },
    });

    for (const asset of assets) {
      const url = keys.get(asset.storageKey) ?? ids.get(asset.id);
      if (url) hashes.set(url, asset.blurHash);
    }
    return hashes;
  }

  /**
   * The asset a URL of ours points at, or null.
   *
   * For callers that need to record the link rather than merely claim the
   * upload — chat attachments, which are authorised through it later.
   */
  async resolveAssetId(url: string, ownerId: string): Promise<string | null> {
    const id = this.idFromPrivateUrl(url);
    if (id) {
      const owned = await this.prisma.mediaAsset.findFirst({
        where: { id, ownerId },
        select: { id: true },
      });
      return owned?.id ?? null;
    }

    const key = this.keyFromUrl(url);
    if (!key) return null;
    const asset = await this.prisma.mediaAsset.findFirst({
      where: { storageKey: key, ownerId },
      select: { id: true },
    });
    return asset?.id ?? null;
  }

  // ── Attachment ────────────────────────────────────────────────────────────

  /**
   * Claim the assets a just-saved row points at.
   *
   * Called by whichever feature persisted the URL — creating a product, a
   * story, saving an avatar. Until this runs the asset is PENDING and the
   * sweeper considers it abandoned; afterwards it is referenced and kept.
   *
   * Deliberately forgiving: a URL that is not ours (the demo dataset is full
   * of external links), or one owned by somebody else, is skipped rather than
   * raised. The caller has already written its row — failing here would undo a
   * successful publish over bookkeeping.
   */
  async markAttached(
    ownerId: string,
    urls: readonly (string | null | undefined)[],
  ): Promise<number> {
    const keys: string[] = [];
    const ids: string[] = [];

    for (const url of urls) {
      if (!url) continue;
      const key = this.keyFromUrl(url);
      if (key) keys.push(key);
      const id = this.idFromPrivateUrl(url);
      if (id) ids.push(id);
    }
    if (!keys.length && !ids.length) return 0;

    const result = await this.prisma.mediaAsset.updateMany({
      where: {
        ownerId,
        status: MediaAssetStatus.PENDING,
        OR: [
          ...(keys.length ? [{ storageKey: { in: keys } }] : []),
          ...(ids.length ? [{ id: { in: ids } }] : []),
        ],
      },
      data: { status: MediaAssetStatus.ATTACHED, attachedAt: new Date() },
    });
    return result.count;
  }

  // ── URLs ──────────────────────────────────────────────────────────────────

  /**
   * The URL a client should store and render.
   *
   * `origin` is the request's own when nothing is configured — the only value
   * that is correct from all three addresses the API answers on in
   * development. A private asset gets an authorised path rather than a file
   * path, because there is no URL for one that should work without a session.
   */
  urlFor(asset: MediaAsset, origin: string): string {
    const base = this.originFor(origin);
    return asset.visibility === MediaVisibility.PUBLIC
      ? `${base}${this.storage.publicUrl(asset.storageKey)}`
      : `${base}/media/${asset.id}/file`;
  }

  /**
   * The URL for a resized copy, or the original when that width was never
   * generated — an upload already smaller than the variant, a non-image, or a
   * row written before derivatives existed.
   */
  variantUrlFor(asset: MediaAsset, origin: string, width: number): string {
    if (!asset.variants.includes(width)) return this.urlFor(asset, origin);

    const base = this.originFor(origin);
    return asset.visibility === MediaVisibility.PUBLIC
      ? `${base}${this.storage.publicUrl(variantKeyFor(asset.storageKey, width))}`
      : `${base}/media/${asset.id}/file?w=${width}`;
  }

  /**
   * Bytes for one resized copy of a private asset, falling back to the
   * original when that width was never generated — a client guessing at a
   * variant must not be able to break an image that exists.
   */
  async readPrivateVariant(
    id: string,
    actor: AuthUser,
    width: number,
  ): Promise<{ asset: MediaAsset; bytes: Buffer; mimeType: string }> {
    const { asset, bytes } = await this.readPrivate(id, actor);
    if (!asset.variants.includes(width)) {
      return { asset, bytes, mimeType: asset.mimeType };
    }
    return {
      asset,
      bytes: await this.storage.read(
        variantKeyFor(asset.storageKey, width),
        asset.visibility,
      ),
      // The copies are WebP whatever the original was.
      mimeType: 'image/webp',
    };
  }

  private originFor(requestOrigin: string): string {
    const configured = (
      this.config.get<string>('media.publicOrigin') ?? ''
    ).trim();
    return (configured || requestOrigin).replace(/\/+$/, '');
  }

  /** `…/media/files/2026/08/<uuid>.jpg` → `2026/08/<uuid>.jpg`. */
  private keyFromUrl(url: string): string | null {
    const base = (
      this.config.get<string>('media.publicBaseUrl') ?? '/media/files'
    ).replace(/\/+$/, '');
    const marker = `${base}/`;
    const at = url.indexOf(marker);
    if (at === -1) return null;
    // Matched on the suffix rather than the whole URL on purpose: the origin a
    // row was written under is not the origin it is read back under, and a LAN
    // address changing must not orphan every photograph taken before it did.
    const key = url.slice(at + marker.length).split(/[?#]/)[0];
    return key || null;
  }

  /** `…/media/<uuid>/file` → `<uuid>`. */
  private idFromPrivateUrl(url: string): string | null {
    const match = url.match(
      /\/media\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/file/i,
    );
    return match ? match[1].toLowerCase() : null;
  }

  // ── Quota ─────────────────────────────────────────────────────────────────

  private async assertUnderDailyQuota(ownerId: string): Promise<void> {
    const ceiling = this.config.get<number>('media.dailyUploadsPerUser')!;
    if (ceiling <= 0) return;

    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const used = await this.prisma.mediaAsset.count({
      where: { ownerId, createdAt: { gte: since } },
    });
    if (used >= ceiling) {
      throw new PayloadTooLargeException('MEDIA_DAILY_QUOTA_EXCEEDED');
    }
  }

  // ── Housekeeping ──────────────────────────────────────────────────────────

  /**
   * Delete uploads nothing ever referenced.
   *
   * Row first, bytes second would leak a file whenever the delete failed after
   * the commit; bytes first, row second leaves a row pointing at nothing,
   * which the reader already treats as a 404 and which the next sweep clears.
   * The second failure mode is the recoverable one, so that is the order.
   */
  async sweepOrphans(now = new Date()): Promise<number> {
    const ttlHours = this.config.get<number>('media.orphanTtlHours')!;
    const cutoff = new Date(now.getTime() - ttlHours * 60 * 60 * 1000);

    const stale = await this.prisma.mediaAsset.findMany({
      where: { status: MediaAssetStatus.PENDING, createdAt: { lt: cutoff } },
      take: 500,
    });
    if (!stale.length) return 0;

    let removed = 0;
    for (const asset of stale) {
      try {
        await this.storage.remove(asset.storageKey, asset.visibility);
        // The resized copies go with it. They are invisible to this sweep
        // otherwise: nothing but the original has a row.
        for (const width of asset.variants) {
          await this.storage
            .remove(variantKeyFor(asset.storageKey, width), asset.visibility)
            .catch(() => undefined);
        }
        await this.prisma.mediaAsset.delete({ where: { id: asset.id } });
        removed += 1;
      } catch (error) {
        this.logger.warn(
          `Could not sweep media asset ${asset.id}: ${String(error)}`,
        );
      }
    }
    if (removed) {
      this.logger.log(`Swept ${removed} unreferenced media asset(s)`);
    }
    return removed;
  }
}

/**
 * `2026/08/<uuid>.jpg` → `2026/08/<uuid>@480.webp`.
 *
 * A convention rather than a stored path, so a client holding nothing but a
 * URL can ask for a smaller copy of it. Always WebP: one format keeps the
 * derivation and the client's guess in step, and it is a third smaller than
 * the JPEG it replaces on exactly the connections that need the help.
 */
export function variantKeyFor(key: string, width: number): string {
  const withoutExtension = key.replace(/\.[a-z0-9]+$/i, '');
  return `${withoutExtension}@${width}.webp`;
}
