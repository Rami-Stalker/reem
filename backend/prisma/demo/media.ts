/**
 * Every image URL the demo dataset produces is built here.
 *
 * Why one module: the seed used to hardcode a handful of `images.unsplash.com`
 * photo ids, and two of them had already 404'd — the app rendered broken cards
 * with no way to tell from the data that anything was wrong. Routing all demo
 * media through one factory means swapping the host (to the project's own
 * object storage, once media upload lands) is a single edit here.
 *
 * The source is deterministic: the same `lock` always returns the same photo,
 * so re-seeding does not reshuffle the catalog's imagery.
 *
 * Q84–Q88 P1 — real product photography must be 4:5 on a light plain
 * background with no models or faces. Placeholder stock cannot honour the
 * content rules, but it does honour the aspect ratio, so layouts built against
 * this data match production.
 */

const HOST = 'https://loremflickr.com';

/** 4:5 — the mandated product photo ratio. */
const PRODUCT_SIZE = { width: 900, height: 1125 };
/** 9:16 — full-bleed story canvas. */
const STORY_SIZE = { width: 720, height: 1280 };

function url(
  topic: string,
  lock: number,
  size: { width: number; height: number },
): string {
  const keywords = encodeURIComponent(topic);
  return `${HOST}/${size.width}/${size.height}/${keywords}/all?lock=${lock}`;
}

/** Stable lock derived from a label, so callers never juggle magic numbers. */
export function lockOf(label: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < label.length; i += 1) {
    hash ^= label.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0) % 100_000;
}

export function productImage(topic: string, label: string): string {
  return url(topic, lockOf(label), PRODUCT_SIZE);
}

export function storyImage(topic: string, label: string): string {
  return url(topic, lockOf(label), STORY_SIZE);
}

export function bannerImage(topic: string, label: string): string {
  return url(topic, lockOf(label), { width: 1200, height: 600 });
}

/**
 * A department plate on the home rail — landscape, because the tile is a wide
 * framed shelf rather than a medallion. Categories shipped with no imagery at
 * all, which left "Shop by category" permanently collapsed: the section only
 * renders departments that have a picture.
 */
export function categoryImage(topic: string, label: string): string {
  return url(topic, lockOf(`category:${label}`), { width: 552, height: 368 });
}

/**
 * Profile pictures and store logos use decorative imagery (florals, fabric,
 * pastel texture) rather than portraits — the platform is women-only and the
 * client's content policy keeps faces out of the product surface entirely.
 */
export function avatarImage(label: string): string {
  const topics = [
    'flowers,pastel',
    'roses,pink',
    'silk,texture',
    'peony,soft',
    'marble,blush',
  ];
  const topic = topics[lockOf(label) % topics.length];
  return url(topic, lockOf(`avatar:${label}`), { width: 400, height: 400 });
}

export function storeLogo(label: string): string {
  return url('boutique,elegant', lockOf(`logo:${label}`), {
    width: 400,
    height: 400,
  });
}
