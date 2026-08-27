import { Injectable, Logger } from '@nestjs/common';
import { encode } from 'blurhash';
import sharp from 'sharp';

export interface Derivative {
  width: number;
  bytes: Buffer;
}

export interface Derivatives {
  variants: Derivative[];
  blurHash: string | null;
}

/**
 * Resized copies of an uploaded photograph, and a blur hash for it.
 *
 * Both are answers to the same problem, at two ends of it. A product grid
 * draws tiles about 180dp wide and was fetching the full 2048px upload for
 * each — several megabytes to render a page of postcards, on connections
 * where that is the difference between a listing that loads and one she backs
 * out of. And while the bytes are on their way, a grey rectangle that pops
 * into a photograph reads as jank; twenty-odd characters of blur hash, drawn
 * from the row itself, reads as loading.
 *
 * Derived on the server from the bytes it received, never accepted from the
 * client — the same rule as sniffing. A thumbnail the uploader supplied could
 * show something other than the image a moderator approved, which on this
 * platform is the whole ball game.
 */
@Injectable()
export class ImageDerivativesService {
  private readonly logger = new Logger(ImageDerivativesService.name);

  /**
   * The widths worth keeping.
   *
   * 480 covers a grid tile and an avatar on a three-times display; 1080 covers
   * a full-width hero and a product detail page. A third size in between would
   * be a third of the storage for a difference nobody can see at these
   * viewport widths.
   */
  static readonly widths = [480, 1080] as const;

  async derive(source: Buffer): Promise<Derivatives> {
    const variants: Derivative[] = [];
    let blurHash: string | null = null;

    try {
      const image = sharp(source, { failOn: 'error' });
      const meta = await image.metadata();
      const originalWidth = meta.width ?? 0;

      for (const width of ImageDerivativesService.widths) {
        // Never upscale. A 300px logo resized "up" to 1080 is a larger file
        // that looks worse, and the client falls back to the original when a
        // variant is absent.
        if (originalWidth === 0 || originalWidth <= width) continue;
        variants.push({
          width,
          bytes: await sharp(source)
            .rotate() // honour EXIF orientation before it is stripped
            .resize({ width, withoutEnlargement: true })
            .webp({ quality: 78 })
            .toBuffer(),
        });
      }

      blurHash = await this.blurHash(source);
    } catch (error) {
      // A file the sniffer accepted but the decoder cannot read — a truncated
      // upload, an exotic sub-format. The original is already stored and
      // serves fine; derivatives are an optimisation and must never be the
      // reason an upload fails.
      this.logger.warn(`Could not derive from an image: ${String(error)}`);
    }

    return { variants, blurHash };
  }

  /**
   * Encoded from a deliberately tiny raster: the hash keeps four components
   * across and three down, so anything past a few dozen pixels is detail the
   * format throws away, and decoding a 12-megapixel photograph to reach it
   * would be the most expensive part of an upload.
   */
  private async blurHash(source: Buffer): Promise<string | null> {
    try {
      const { data, info } = await sharp(source)
        .rotate()
        .resize(32, 32, { fit: 'inside' })
        .ensureAlpha()
        .raw()
        .toBuffer({ resolveWithObject: true });

      return encode(
        new Uint8ClampedArray(data),
        info.width,
        info.height,
        4,
        3,
      );
    } catch (error) {
      this.logger.warn(`Could not hash an image: ${String(error)}`);
      return null;
    }
  }
}
