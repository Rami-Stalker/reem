import { Controller, Get, Logger, Param, Req, Res } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Throttle } from '@nestjs/throttler';
import { randomBytes } from 'node:crypto';
import type { Request, Response } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { AppLinksService } from './app-links.service';
import {
  renderLandingPage,
  renderMessagePage,
  safeSchemeUrl,
} from './landing-page';
import { SharePreviewService } from './share-preview.service';
import { SHARE_PATHS, ShareLinkKind, schemeUrl } from './share-links';

/**
 * Where a shared Reem link lands.
 *
 * Every one of these URLs used to end on the browser's own error page. Not
 * because a route was missing — because the host they pointed at,
 * `https://reem.shop`, has never existed: it is NXDOMAIN, so nothing resolved,
 * WhatsApp drew no preview, and the tap failed before any server was reached.
 * The links point at this API's origin now (see `config.links.publicOrigin`),
 * and this controller is what answers them.
 *
 * ## Three audiences, one URL
 *
 * A messenger's crawler wants `<head>`. A browser wants a page. A phone with
 * Reem installed wants never to get here at all — App Links and Universal
 * Links hand the URL straight to the app, and the well-known files that make
 * that work are served from here too.
 *
 * ## Why these render HTML instead of throwing
 *
 * `AllExceptionsFilter` turns every thrown error into the JSON envelope, which
 * is precisely the "page" this work exists to remove. A link to something
 * deleted, private or mistyped is a normal event — a forwarded message is old
 * by definition — so it renders a branded 404 rather than raising.
 */
@Controller()
export class LinksController {
  private readonly logger = new Logger(LinksController.name);

  constructor(
    private readonly previews: SharePreviewService,
    private readonly appLinks: AppLinksService,
    private readonly config: ConfigService,
  ) {
    this.appLinks.warnIfUnconfigured();
  }

  // ── Platform association files ──────────────────────────────────────────

  /**
   * Generous throttling: Google's verifier, Apple's CDN and every install of
   * the app fetch these, and a 429 here is indistinguishable from the file
   * being absent — which means App Links quietly stop verifying.
   */
  @Public()
  @Throttle({ default: { limit: 600, ttl: 60_000 } })
  @Get('.well-known/assetlinks.json')
  assetLinks(@Res() res: Response) {
    this.serveAssociation(res, this.appLinks.assetLinks());
  }

  @Public()
  @Throttle({ default: { limit: 600, ttl: 60_000 } })
  @Get('.well-known/apple-app-site-association')
  appleAppSiteAssociation(@Res() res: Response) {
    this.serveAssociation(res, this.appLinks.appleAppSiteAssociation());
  }

  // ── Landing pages ───────────────────────────────────────────────────────

  @Public()
  @Get('product/:id')
  product(@Param('id') id: string, @Req() req: Request, @Res() res: Response) {
    return this.render('product', { id }, req, res);
  }

  @Public()
  @Get('p/:id')
  content(@Param('id') id: string, @Req() req: Request, @Res() res: Response) {
    return this.render('content', { id }, req, res);
  }

  @Public()
  @Get('user/:id')
  profile(@Param('id') id: string, @Req() req: Request, @Res() res: Response) {
    return this.render('profile', { id }, req, res);
  }

  /** The short form. Canonicalised by the page's `<link rel="canonical">`. */
  @Public()
  @Get('u/:id')
  profileAlias(@Param('id') id: string, @Req() req: Request, @Res() res: Response) {
    return this.render('profile', { id }, req, res);
  }

  @Public()
  @Get('user/:id/products')
  storefront(@Param('id') id: string, @Req() req: Request, @Res() res: Response) {
    return this.render('storefront', { id }, req, res);
  }

  @Public()
  @Get('collection/:key')
  collection(
    @Param('key') key: string,
    @Req() req: Request,
    @Res() res: Response,
  ) {
    return this.render('collection', { key }, req, res);
  }

  /**
   * A room invite. `POST /rooms/join/:slug` on `RoomsController` is the
   * endpoint that actually admits her; this is the same address read with GET,
   * which is what a browser does, and the two cannot collide.
   */
  @Public()
  @Get('rooms/join/:slug')
  roomInvite(
    @Param('slug') slug: string,
    @Req() req: Request,
    @Res() res: Response,
  ) {
    return this.render('room-invite', { slug }, req, res);
  }

  /**
   * الصالونات والجمال.
   *
   * Not `ParseUUIDPipe`: a salon is reachable by its slug, which is what a
   * forwarded link carries and what makes it readable in a message.
   */
  @Public()
  @Get('salons/:id')
  salon(@Param('id') id: string, @Req() req: Request, @Res() res: Response) {
    return this.render('salon', { id }, req, res);
  }

  @Public()
  @Get('invite/:code')
  referral(
    @Param('code') code: string,
    @Req() req: Request,
    @Res() res: Response,
  ) {
    return this.render('referral', { code }, req, res);
  }

  /**
   * The bare origin.
   *
   * Reached by anyone who trims a shared link back to the host — which people
   * do — and by every preview crawler that probes the site root for a name and
   * an icon. It answered a JSON 404 before.
   */
  @Public()
  @Get()
  home(@Req() req: Request, @Res() res: Response) {
    const origin = this.originFor(req);
    const store =
      this.config.get<string>('links.android.storeUrl') ||
      this.config.get<string>('links.ios.storeUrl') ||
      this.config.get<string>('links.apkUrl') ||
      '';
    res.status(200);
    this.htmlHeaders(res, null);
    res.send(
      renderMessagePage({
        canonicalUrl: `${origin}/`,
        headline: 'ريم',
        detail:
          'سوق نسائي للأزياء والجمال. افتحي رابط منتج أو منشور لمشاهدته، أو حمّلي التطبيق.',
        cta: store ? { label: 'حمّلي تطبيق ريم', url: store } : null,
        noindex: false,
      }),
    );
  }

  // ── Rendering ───────────────────────────────────────────────────────────

  private async render(
    kind: ShareLinkKind,
    params: Record<string, string>,
    req: Request,
    res: Response,
  ): Promise<void> {
    const origin = this.originFor(req);
    const nonce = randomBytes(16).toString('base64');
    const scheme = this.config.get<string>('links.scheme') ?? 'reem';

    let preview: Awaited<ReturnType<SharePreviewService['resolve']>> = null;
    let failed = false;
    try {
      preview = await this.previews.resolve(kind, params, origin);
    } catch (error) {
      // A resolver throwing is an outage, not a dead link, and telling her the
      // product was removed would be a lie that costs a sale. It is logged
      // loudly and the page says to try again.
      failed = true;
      this.logger.error(
        `Failed to resolve a ${kind} share link`,
        error instanceof Error ? error.stack : String(error),
      );
    }

    if (!preview) {
      res.status(failed ? 503 : 404);
      this.htmlHeaders(res, nonce);
      res.send(
        renderMessagePage({
          canonicalUrl: `${origin}${req.path}`,
          headline: failed
            ? 'تعذّر فتح الرابط'
            : 'لم نجد هذا الرابط',
          detail: failed
            ? 'حدث خلل مؤقّت عندنا. حاولي مرّة أخرى بعد قليل.'
            : NOT_FOUND_DETAIL[kind],
          cta: { label: 'تصفّحي ريم', url: `${origin}/` },
        }),
      );
      return;
    }

    const deepLink =
      safeSchemeUrl(schemeUrl(scheme, preview.kind, params), scheme) ??
      `${scheme}://home`;

    res.status(200);
    this.htmlHeaders(res, nonce);
    res.send(
      renderLandingPage({
        preview,
        canonicalUrl: `${origin}${preview.path}`,
        schemeUrl: deepLink,
        androidStoreUrl: this.config.get<string>('links.android.storeUrl'),
        iosStoreUrl: this.config.get<string>('links.ios.storeUrl'),
        apkUrl: this.config.get<string>('links.apkUrl'),
        nonce,
      }),
    );
  }

  private serveAssociation(res: Response, body: unknown): void {
    res.type('application/json');
    // Long enough that the verifiers are not hammering a free instance,
    // short enough that adding a fingerprint takes effect the same day.
    res.setHeader('Cache-Control', 'public, max-age=3600');
    res.send(JSON.stringify(body));
  }

  /**
   * Headers for an HTML response from an API that is otherwise pure JSON.
   *
   * The Content-Security-Policy is set per response rather than inherited from
   * helmet's global one, which is right for this API and wrong for this page in
   * two specific ways: `img-src 'self'` would block every product photograph
   * (they are served from Supabase Storage on another origin) and
   * `script-src 'self'` would block the one inline script the «افتح في
   * التطبيق» button needs. A nonce lets exactly that script run and nothing
   * else — an injected `<script>` without the nonce still does not execute.
   */
  private htmlHeaders(res: Response, nonce: string | null): void {
    res.type('text/html; charset=utf-8');
    res.setHeader(
      'Content-Security-Policy',
      [
        "default-src 'none'",
        "img-src https: data:",
        "style-src 'unsafe-inline'",
        nonce ? `script-src 'nonce-${nonce}'` : "script-src 'none'",
        "base-uri 'none'",
        "form-action 'none'",
        "frame-ancestors 'none'",
      ].join('; '),
    );
    // A shared link is forwarded for weeks. Cached briefly so a burst of taps
    // on one message does not become a burst of queries, and revalidated often
    // enough that a price change shows up.
    res.setHeader('Cache-Control', 'public, max-age=300, s-maxage=300');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    // helmet defaults this to `same-origin`, which is correct for the API and
    // would stop a crawler reading the document it was pointed at.
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  }

  /**
   * The origin links are written with.
   *
   * Configuration wins, because the value has to match the host the apps
   * declare in their App Links: deriving it from the request would mean a link
   * opened via a bare IP or a preview domain writes a canonical URL that no
   * phone will ever hand to the app. The request is only the fallback for
   * development, where nobody has configured anything.
   */
  private originFor(req: Request): string {
    const configured = (
      this.config.get<string>('links.publicOrigin') ?? ''
    ).replace(/\/+$/, '');
    if (configured) return configured;
    return `${req.protocol}://${req.get('host') ?? 'localhost'}`;
  }
}

const NOT_FOUND_DETAIL: Record<ShareLinkKind, string> = {
  product: 'قد تكون البائعة أزالت هذا المنتج أو لم يعد معروضاً.',
  content: 'قد يكون المنشور حُذف أو أصبح خاصاً، أو انتهت صلاحية القصة.',
  profile: 'قد تكون صاحبة الصفحة جعلتها خاصة.',
  storefront: 'قد تكون صاحبة المتجر جعلت صفحتها خاصة.',
  collection: 'هذه المجموعة لم تعد موجودة.',
  'room-invite': 'قد تكون صاحبة الغرفة أوقفت الدعوة.',
  referral: 'انتهت صلاحية رمز الدعوة أو لم يعد مفعّلاً.',
  salon: 'قد يكون الصالون أغلق صفحته أو لم يعد متاحاً.',
};

/** Re-exported so `SHARE_PATHS` and the routes above cannot drift unnoticed. */
export const LINKS_ROUTE_PATHS = SHARE_PATHS;
