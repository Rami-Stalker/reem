import { MediaAsset } from '@prisma/client';

/**
 * `url` and `thumbnail_url` are passed in rather than read off the row: both
 * depend on the origin the request arrived on, which a database row cannot
 * know. See `MediaService.urlFor` and `variantUrlFor`.
 */
export function serializeMediaAsset(
  asset: MediaAsset,
  url: string,
  thumbnailUrl: string,
) {
  return {
    id: asset.id,
    url,
    /// The smallest copy that exists, or the original when none does. A client
    /// showing a grid should ask for this and nothing else.
    thumbnail_url: thumbnailUrl,
    /// Widths available, so a client that knows its own layout can pick.
    variants: asset.variants,
    /// Drawn while the bytes are in flight.
    blur_hash: asset.blurHash,
    type: asset.kind,
    mime_type: asset.mimeType,
    byte_size: asset.byteSize,
    width: asset.width,
    height: asset.height,
    visibility: asset.visibility,
    purpose: asset.purpose,
    created_at: asset.createdAt.toISOString(),
  };
}
