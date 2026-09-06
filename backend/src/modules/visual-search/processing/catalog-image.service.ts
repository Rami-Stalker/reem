import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { lookup } from 'node:dns/promises';
import { isIP } from 'node:net';
import { MediaService } from '../../media/media.service';

/**
 * Getting the bytes of a catalogue photograph.
 *
 * Two sources, in order, and the order is the security story:
 *
 *  1. **Ours.** A URL that resolves to a `MediaAsset` this platform stored is
 *     read straight off the storage driver. No network, no risk, and it is
 *     where every image uploaded through `/media/uploads` lives.
 *  2. **Somewhere else.** Product rows may carry external links — the demo
 *     dataset is entirely external, and a seller migrating a listing can paste
 *     one. Fetching those is a request the server makes to an address a *user*
 *     supplied, which is the shape of every SSRF there has ever been.
 *
 * So the outbound path is fenced:
 *
 *  - `http`/`https` only. No `file:`, no `gopher:`, no `data:`.
 *  - The hostname is resolved **before** the request and the resulting address
 *    checked against the private, loopback, link-local and carrier-grade NAT
 *    ranges. That is what stops `http://169.254.169.254/…` and
 *    `http://127.0.0.1:5432` reaching anything.
 *  - Redirects are followed **by hand**, at most three hops, with the address
 *    check re-run on every one. `redirect: 'error'` was the safe answer and it
 *    was also the wrong one: image hosts redirect as a matter of routine — a
 *    CDN edge, a signed URL, the placeholder service this dataset uses — so
 *    refusing outright meant those listings silently never became searchable
 *    by picture, which is how the catalogue ended up with an empty index and
 *    the screen kept saying it was not ready yet. Following a hop only after
 *    resolving *its* host to a public address is what keeps the fence up.
 *  - A hard timeout and a hard byte ceiling, enforced while reading rather
 *    than from a `Content-Length` header a server is free to lie about.
 *  - The bytes are only ever handed to `sharp` and turned into a vector.
 *    Nothing fetched here is served back to anybody.
 *
 * The residual risk is DNS rebinding between the lookup and the connection.
 * Closing it properly means pinning the resolved address on the socket, which
 * `fetch` does not expose; the mitigation is that the response is never
 * echoed, so a successful rebind yields an attacker an image decode and
 * nothing else.
 */
@Injectable()
export class CatalogImageService {
  private readonly logger = new Logger(CatalogImageService.name);

  /** Hops allowed before a redirect chain is treated as a loop. */
  private static readonly maxRedirects = 3;

  constructor(
    private readonly media: MediaService,
    private readonly config: ConfigService,
  ) {}

  private get allowRemote(): boolean {
    return this.config.get<boolean>('visualSearch.indexRemoteImages') ?? true;
  }

  private get maxBytes(): number {
    return this.config.get<number>('visualSearch.maxImageBytes') ?? 8 * 1024 * 1024;
  }

  private get timeoutMs(): number {
    return this.config.get<number>('visualSearch.fetchTimeoutMs') ?? 6000;
  }

  /** Bytes for one product photograph, or null when they cannot be had. */
  async read(url: string): Promise<Buffer | null> {
    const own = await this.media.readPublicByUrl(url);
    if (own) return own;

    if (!this.allowRemote) return null;
    return this.fetchRemote(url);
  }

  private async fetchRemote(url: string): Promise<Buffer | null> {
    let parsed: URL;
    try {
      parsed = new URL(url);
    } catch {
      return null;
    }
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') return null;
    if (!(await this.resolvesToPublicAddress(parsed.hostname))) {
      this.logger.warn(`Refused to index an image at a non-public address: ${parsed.hostname}`);
      return null;
    }

    const controller = new AbortController();
    // One deadline for the whole exchange, redirects included — otherwise a
    // chain of hops each just inside the limit adds up to a stalled sweep.
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const response = await this.followedFetch(parsed, controller.signal);
      if (!response || !response.ok || !response.body) return null;

      const reader = response.body.getReader();
      const chunks: Uint8Array[] = [];
      let total = 0;

      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        total += value.length;
        if (total > this.maxBytes) {
          await reader.cancel();
          this.logger.debug(`Abandoned an oversized catalogue image: ${url}`);
          return null;
        }
        chunks.push(value);
      }

      return Buffer.concat(chunks.map((chunk) => Buffer.from(chunk)));
    } catch (error) {
      this.logger.debug(`Could not fetch a catalogue image (${String(error)}): ${url}`);
      return null;
    } finally {
      clearTimeout(timer);
    }
  }

  /**
   * Fetches [url], following redirects one at a time so each destination can
   * be checked before it is contacted. Returns null when a hop points
   * somewhere it must not, or when the chain runs longer than it should.
   */
  private async followedFetch(
    url: URL,
    signal: AbortSignal,
  ): Promise<Response | null> {
    let target = url;

    for (let hop = 0; hop <= CatalogImageService.maxRedirects; hop += 1) {
      const response = await fetch(target.toString(), {
        signal,
        redirect: 'manual',
        headers: { accept: 'image/*' },
      });

      const location = response.headers.get('location');
      const isRedirect = response.status >= 300 && response.status < 400;
      if (!isRedirect || !location) return response;

      let next: URL;
      try {
        next = new URL(location, target);
      } catch {
        return null;
      }
      if (next.protocol !== 'http:' && next.protocol !== 'https:') return null;
      if (!(await this.resolvesToPublicAddress(next.hostname))) {
        this.logger.warn(
          `Refused a redirect to a non-public address: ${next.hostname}`,
        );
        return null;
      }
      target = next;
    }

    this.logger.debug(`Gave up on a redirect chain: ${url.toString()}`);
    return null;
  }

  private async resolvesToPublicAddress(hostname: string): Promise<boolean> {
    try {
      const literal = isIP(hostname);
      const addresses = literal
        ? [{ address: hostname, family: literal }]
        : await lookup(hostname, { all: true });
      return addresses.length > 0 && addresses.every((entry) => isPublicAddress(entry.address));
    } catch {
      return false;
    }
  }
}

/** True for an address outside every range that means "inside the building". */
export function isPublicAddress(address: string): boolean {
  const version = isIP(address);
  if (version === 4) {
    const octets = address.split('.').map(Number);
    if (octets.length !== 4 || octets.some((part) => !Number.isInteger(part))) return false;
    const [a, b] = octets;

    if (a === 0 || a === 10 || a === 127) return false;
    if (a === 169 && b === 254) return false; // link-local, and the cloud metadata endpoint
    if (a === 172 && b >= 16 && b <= 31) return false;
    if (a === 192 && b === 168) return false;
    if (a === 100 && b >= 64 && b <= 127) return false; // carrier-grade NAT
    if (a >= 224) return false; // multicast and reserved
    return true;
  }

  if (version === 6) {
    const normalised = address.toLowerCase();
    if (normalised === '::' || normalised === '::1') return false;
    // Unique-local (fc00::/7), link-local (fe80::/10), and IPv4-mapped, which
    // would otherwise smuggle 127.0.0.1 past the check above.
    if (/^f[cd]/.test(normalised)) return false;
    if (/^fe[89ab]/.test(normalised)) return false;
    if (normalised.startsWith('::ffff:')) return isPublicAddress(normalised.slice(7));
    return true;
  }

  return false;
}
