import { Injectable } from '@nestjs/common';
import { MediaAsset, MediaVisibility } from '@prisma/client';
import { MediaService } from '../../../../backend/src/modules/media/media.service';
import { supabaseRuntime } from '../runtime/env';

/**
 * `MediaService`, with URLs that point where things live on Supabase.
 *
 * On a server one origin serves both kinds of URL: public files off the
 * static mount and private ones through `/media/:id/file`. On Supabase they
 * are two hosts' worth of path apart — public objects are served by Storage
 * (`<project>/storage/v1/object/public/…`), private bytes by this function
 * (`<project>/functions/v1/api/media/:id/file`). The backend composes both from
 * a single `MEDIA_PUBLIC_ORIGIN`, so this subclass keeps its public branch and
 * gives the private branch the function's own address.
 *
 * Everything else — upload, sniffing, quotas, claiming, sweeping,
 * authorisation — is the backend's code, inherited untouched. The constructor
 * is inherited too, and with it the injection metadata.
 */
@Injectable()
export class EdgeMediaService extends MediaService {
  override urlFor(asset: MediaAsset, origin: string): string {
    if (asset.visibility === MediaVisibility.PUBLIC) return super.urlFor(asset, origin);
    return `${this.functionBase()}/media/${asset.id}/file`;
  }

  override variantUrlFor(asset: MediaAsset, origin: string, width: number): string {
    if (asset.visibility === MediaVisibility.PUBLIC) {
      return super.variantUrlFor(asset, origin, width);
    }
    const url = this.urlFor(asset, origin);
    return asset.variants.includes(width) ? `${url}?w=${width}` : url;
  }

  private functionBase(): string {
    const { url, functionName } = supabaseRuntime();
    return `${url}/functions/v1/${functionName}`;
  }
}
