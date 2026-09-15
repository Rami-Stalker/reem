import type { NextFunction, Request, Response } from 'express';

/**
 * Whether this deployment can decode photographs.
 *
 * The backend decodes, crops and resizes images with sharp (libvips), which an
 * edge isolate cannot load (see `runtime/sharp.ts`). Nothing that depends on
 * it was removed: resized copies and blur hashes are simply not produced, and
 * searching by photograph is switched off here — at the edge, with an honest
 * answer — rather than failing deep inside with "IMAGE_UNREADABLE", which
 * would tell a woman her photo was the problem.
 *
 * To bring both back later, replace the shim behind `sharp` in `build.mjs`
 * with a real engine (a WASM decoder/resizer, or an image service) and set
 * `REEM_IMAGE_ENGINE=available` on the function. On a server of our own the
 * backend uses sharp directly and none of this applies.
 */
export function imageEngineAvailable(): boolean {
  return process.env.REEM_IMAGE_ENGINE === 'available';
}

/** Routes that must decode a photograph the client sends. */
const NEEDS_DECODER = [
  /^\/visual-search\/searches\/?$/,
  /^\/visual-search\/sessions\/[^/]+\/refine\/?$/,
  /^\/visual-search\/try-on\/?$/,
];

export function imageEngineGate(req: Request, res: Response, next: NextFunction) {
  if (imageEngineAvailable()) return next();
  const path = req.path;

  if (req.method === 'POST' && NEEDS_DECODER.some((pattern) => pattern.test(path))) {
    res.status(503).json({
      statusCode: 503,
      error: 'Service Unavailable',
      code: 'IMAGE_ENGINE_UNAVAILABLE',
      message: 'البحث بالصورة غير متاح حالياً.',
    });
    return;
  }

  if (req.method === 'GET' && /^\/visual-search\/bootstrap\/?$/.test(path)) {
    // The screen reads `ready`; say plainly that searching by photo is off.
    const json = res.json.bind(res);
    res.json = (body: unknown) => {
      if (body && typeof body === 'object') {
        Object.assign(body as Record<string, unknown>, { ready: false, image_engine: 'unavailable' });
      }
      return json(body);
    };
  }
  next();
}
