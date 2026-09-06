import {
  BadRequestException,
  Injectable,
  Logger,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MediaType } from '@prisma/client';
import { createHash } from 'node:crypto';
import sharp from 'sharp';
import type { Metadata, Sharp } from 'sharp';
import { sniffMedia } from '../../media/media-sniffer';
import { CANVAS, RawImage } from '../embedding/image-signals';
import { EmbeddableImage } from '../embedding/visual-embedder';

/** A region of an image in normalised 0–1 coordinates. */
export interface BoundingBox {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface PreparedImage extends EmbeddableImage {
  width: number;
  height: number;
  /** Bytes of the re-encoded copy, which is what gets stored if anything does. */
  byteSize: number;

  /**
   * The whole frame squashed onto the canvas, present only when asked for.
   *
   * Distorted on purpose. `raw` is cropped by salience, which is right for a
   * descriptor and useless for geometry: a box measured on it cannot be mapped
   * back to the photograph it came from. This one is `fit: 'fill'`, so canvas
   * row ÷ 224 is exactly source row ÷ height and a band the segmenter finds
   * can be cropped out of the original. Aspect distortion does not disturb the
   * row statistics it is read with.
   */
  frame: RawImage | null;
}

/**
 * Everything that happens to a photograph before anybody looks at it.
 *
 * One service, because these steps are not independent and doing them in the
 * wrong order is how an image pipeline becomes a security problem:
 *
 *   1. **Sniff.** The bytes decide what the file is. A client's `Content-Type`
 *      is a claim; `sniffMedia` is evidence. Same rule as `MediaService`, and
 *      the same function, so the two can never drift.
 *   2. **Bound.** A ceiling on the encoded size *and* on the decoded pixel
 *      count. The second one matters more: a 40 KB PNG can decode to a
 *      gigabyte, and a decoder that is handed one takes the process with it.
 *   3. **Re-encode.** Every image is decoded and written out again as WebP at
 *      a bounded size. That strips EXIF — including the GPS tag on a
 *      photograph taken at her home — flattens any exotic sub-format, and
 *      means the bytes the platform stores are bytes it produced.
 *   4. **Normalise.** A fixed square canvas, so two descriptors are
 *      comparable. Cropped by salience rather than by the centre: a full-length
 *      Instagram photograph is mostly floor and ceiling, and the garment is
 *      not in the middle of it.
 *
 * `sharp` is already a dependency — it derives the thumbnails and blur hashes
 * every product image gets — so none of this adds a package.
 */
@Injectable()
export class ImageProcessingService {
  private readonly logger = new Logger(ImageProcessingService.name);

  constructor(private readonly config: ConfigService) {}

  private get maxBytes(): number {
    return this.config.get<number>('visualSearch.maxImageBytes') ?? 8 * 1024 * 1024;
  }

  private get maxPixels(): number {
    return this.config.get<number>('visualSearch.maxImagePixels') ?? 40_000_000;
  }

  private get storedWidth(): number {
    return this.config.get<number>('visualSearch.storedWidth') ?? 1024;
  }

  /**
   * Accept a query photograph.
   *
   * Throws — with codes the client already knows how to render — rather than
   * returning null: this is the request boundary, and "her screenshot was a
   * PDF" is something she needs told, not something to search around.
   */
  async prepare(
    buffer: Buffer,
    options: { crop?: BoundingBox; withFrame?: boolean } = {},
  ): Promise<PreparedImage> {
    if (!buffer?.length) throw new BadRequestException('EMPTY_IMAGE');
    if (buffer.length > this.maxBytes) {
      throw new PayloadTooLargeException('IMAGE_TOO_LARGE');
    }

    const sniffed = sniffMedia(buffer);
    if (!sniffed) throw new UnsupportedMediaTypeException('UNSUPPORTED_MEDIA_TYPE');
    if (sniffed.kind !== MediaType.image) {
      throw new UnsupportedMediaTypeException('IMAGE_REQUIRED');
    }

    let source: Sharp;
    let metadata: Metadata;
    try {
      // `limitInputPixels` is the decompression-bomb guard and belongs here
      // rather than in a size check, because the dangerous number is the one
      // after decoding.
      source = sharp(buffer, { failOn: 'error', limitInputPixels: this.maxPixels });
      metadata = await source.metadata();
    } catch (error) {
      this.logger.warn(`Rejected an undecodable image: ${String(error)}`);
      throw new UnsupportedMediaTypeException('IMAGE_UNREADABLE');
    }

    const width = metadata.width ?? 0;
    const height = metadata.height ?? 0;
    // 32px is below any real photograph and above the 1×1 tracking pixels that
    // arrive when a share sheet hands over the wrong part of a page.
    if (width < 32 || height < 32) throw new BadRequestException('IMAGE_TOO_SMALL');

    const cropped = options.crop
      ? await this.extract(buffer, options.crop, width, height)
      : buffer;

    // EXIF orientation is honoured *before* the metadata is dropped, so a
    // photograph taken sideways is described the way she saw it.
    const encoded = await sharp(cropped, { limitInputPixels: this.maxPixels })
      .rotate()
      .resize({
        width: this.storedWidth,
        height: this.storedWidth,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .webp({ quality: 82 })
      .toBuffer();

    const raw = await this.toCanvas(cropped, width, height);
    const frame = options.withFrame ? await this.toFrame(cropped, width, height) : null;

    return {
      buffer: encoded,
      raw,
      frame,
      checksum: createHash('sha256').update(encoded).digest('hex'),
      width,
      height,
      byteSize: encoded.length,
    };
  }

  /**
   * Re-normalise an already-prepared image around one region of it.
   *
   * Used by the outfit path: each detected region is embedded as if it were
   * its own photograph, which is the only way a handbag in the corner of a
   * frame competes with handbags rather than with full-length looks.
   */
  async prepareRegion(buffer: Buffer, crop: BoundingBox): Promise<PreparedImage> {
    return this.prepare(buffer, { crop });
  }

  /**
   * Decode a catalogue image for indexing.
   *
   * Returns null instead of throwing on anything unreadable. A seller's
   * listing with one broken photograph must not stop the indexer working
   * through the other forty thousand.
   */
  async prepareQuietly(buffer: Buffer): Promise<PreparedImage | null> {
    try {
      return await this.prepare(buffer);
    } catch (error) {
      this.logger.debug(`Skipped an image during indexing: ${String(error)}`);
      return null;
    }
  }

  private async extract(
    buffer: Buffer,
    crop: BoundingBox,
    width: number,
    height: number,
  ): Promise<Buffer> {
    const left = Math.max(0, Math.min(width - 1, Math.round(crop.x * width)));
    const top = Math.max(0, Math.min(height - 1, Math.round(crop.y * height)));
    const cropWidth = Math.max(16, Math.min(width - left, Math.round(crop.w * width)));
    const cropHeight = Math.max(16, Math.min(height - top, Math.round(crop.h * height)));

    return sharp(buffer, { limitInputPixels: this.maxPixels })
      .rotate()
      .extract({ left, top, width: cropWidth, height: cropHeight })
      .toBuffer();
  }

  /**
   * The fixed square every descriptor is computed over.
   *
   * `position: attention` is sharp's entropy-driven crop: it keeps the busiest
   * region of the frame, which on a fashion photograph is the garment and not
   * the studio floor. It is deterministic — the same bytes give the same crop —
   * which is what lets an indexed vector be trusted a year later.
   *
   * It is also a deliberate trade, and worth naming. Cropping by salience
   * makes the descriptor **framing-invariant**: a close-up of a dress and a
   * full-length shot of the same dress land on the same canvas and match,
   * which is the single most valuable property when the query is a screenshot
   * cropped by whoever posted it. The cost is that *where a garment sits in
   * its frame* stops being evidence — a skirt shot alone and a floor-length
   * abaya shot alone both fill the square. Length and garment type therefore
   * come from the attribute half (the categories the catalogue neighbours
   * agree on, and anything a vision model proposed), never from the crop.
   * `geometry` keeps the *source* aspect ratio for exactly this reason: it is
   * the one framing fact the crop cannot destroy.
   *
   * `flatten` composites transparency onto white before anything is measured.
   * A PNG cut-out with an alpha channel would otherwise contribute whatever
   * the decoder happened to leave in the RGB planes behind the transparent
   * pixels, which is usually black and is never the garment.
   */
  private async toCanvas(
    buffer: Buffer,
    sourceWidth: number,
    sourceHeight: number,
  ): Promise<RawImage> {
    const { data } = await sharp(buffer, { limitInputPixels: this.maxPixels })
      .rotate()
      .flatten({ background: { r: 255, g: 255, b: 255 } })
      .resize(CANVAS, CANVAS, {
        fit: 'cover',
        position: sharp.strategy.attention,
      })
      .removeAlpha()
      .raw()
      .toBuffer({ resolveWithObject: true });

    return { data, sourceWidth, sourceHeight };
  }

  /** The whole frame, squashed. See `PreparedImage.frame`. */
  private async toFrame(
    buffer: Buffer,
    sourceWidth: number,
    sourceHeight: number,
  ): Promise<RawImage> {
    const { data } = await sharp(buffer, { limitInputPixels: this.maxPixels })
      .rotate()
      .flatten({ background: { r: 255, g: 255, b: 255 } })
      .resize(CANVAS, CANVAS, { fit: 'fill' })
      .removeAlpha()
      .raw()
      .toBuffer({ resolveWithObject: true });

    return { data, sourceWidth, sourceHeight };
  }
}
