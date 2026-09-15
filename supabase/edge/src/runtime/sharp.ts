/**
 * `sharp`, as the backend sees it on the edge.
 *
 * sharp wraps libvips, a native multithreaded library; Supabase's edge runtime
 * cannot load it. Every call site in the backend already treats a decoder
 * failure as an expected outcome:
 *
 *  - `ImageDerivativesService` logs it and stores the upload without resized
 *    copies — clients fall back to the original, by design.
 *  - `ImageProcessingService` answers 415 IMAGE_UNREADABLE — visual search by
 *    photograph is unavailable on this runtime (see docs/SUPABASE.md).
 *
 * Throwing a descriptive error is therefore the whole adapter.
 */
class EdgeImageUnavailable extends Error {
  constructor() {
    super('Image decoding (sharp/libvips) is not available on the Supabase edge runtime');
    this.name = 'EdgeImageUnavailable';
  }
}

function sharp(): never {
  throw new EdgeImageUnavailable();
}

sharp.strategy = { attention: 16, entropy: 17 };
sharp.gravity = { centre: 0, center: 0 };
sharp.fit = { cover: 'cover', contain: 'contain', fill: 'fill', inside: 'inside', outside: 'outside' };

export default sharp;
