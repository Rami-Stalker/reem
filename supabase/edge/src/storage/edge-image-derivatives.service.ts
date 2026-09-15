import { Injectable } from '@nestjs/common';
import { Derivatives, ImageDerivativesService } from '../../../../backend/src/modules/media/image-derivatives';

/**
 * `ImageDerivativesService` without resizing.
 *
 * Resized copies and blur hashes are an optimisation the backend already
 * declares optional: an asset without them serves its original, and every URL
 * the API hands out for a missing width falls back to that original. On the
 * edge there is no libvips to produce them, so this answers "none" up front
 * instead of logging a decoder failure for every photograph uploaded.
 */
@Injectable()
export class EdgeImageDerivativesService extends ImageDerivativesService {
  override async derive(): Promise<Derivatives> {
    return { variants: [], blurHash: null };
  }
}
