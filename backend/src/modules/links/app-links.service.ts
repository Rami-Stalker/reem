import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { appLinkPatterns } from './share-links';

/**
 * The two files that turn an ordinary https link into one that opens the app.
 *
 * Neither is served as a static asset. They are generated, because both are
 * keyed to values that differ per environment — the signing fingerprint of the
 * build, the Apple team id — and a checked-in JSON file with a placeholder in
 * it is the single most reliable way to ship an App Links configuration that
 * silently does not verify.
 *
 * ## The rules the platforms impose, which this satisfies
 *
 * Android fetches `https://<host>/.well-known/assetlinks.json` at install time
 * (and periodically after). It must be `application/json`, must be served over
 * https with a valid certificate, and must not redirect.
 *
 * Apple fetches `https://<host>/.well-known/apple-app-site-association` — no
 * extension, `application/json`, no redirect, and it must be reachable
 * *unauthenticated*, which is why both routes are `@Public()`. Apple's CDN
 * caches it, so it needs to be right before the first build reaches a device.
 *
 * ## Before anything is configured
 *
 * Both answer with a structurally valid, empty document rather than a 404. An
 * empty association is the honest statement "no app claims this host yet": the
 * links keep working as web pages and the landing page's own button keeps
 * opening the app through the custom scheme. A 404 would leave Android
 * retrying and would tell nobody anything.
 */
@Injectable()
export class AppLinksService {
  private readonly logger = new Logger(AppLinksService.name);

  constructor(private readonly config: ConfigService) {}

  assetLinks(): unknown[] {
    const packageName = this.config.get<string>('links.android.packageName');
    const fingerprints =
      this.config.get<string[]>('links.android.fingerprints') ?? [];

    if (fingerprints.length === 0) return [];

    return [
      {
        relation: ['delegate_permission/common.handle_all_urls'],
        target: {
          namespace: 'android_app',
          package_name: packageName,
          sha256_cert_fingerprints: fingerprints,
        },
      },
    ];
  }

  appleAppSiteAssociation(): unknown {
    const appIds = this.config.get<string[]>('links.ios.appIds') ?? [];
    if (appIds.length === 0) {
      return { applinks: { apps: [], details: [] } };
    }

    const components = appLinkPatterns().map((pattern) => ({
      '/': pattern,
      comment: `Ohara share link: ${pattern}`,
    }));

    return {
      applinks: {
        // Required by the format and always empty; Apple reserved it and never
        // used it.
        apps: [],
        details: [{ appIDs: appIds, components }],
      },
      // Declared so a future password-manager association does not need a
      // second round of Apple CDN cache invalidation.
      webcredentials: { apps: appIds },
    };
  }

  /**
   * Warns once at boot when a production deployment is serving empty
   * association files, since the symptom otherwise is "links open the browser"
   * with nothing anywhere saying why.
   */
  warnIfUnconfigured(): void {
    if (this.config.get<string>('nodeEnv') !== 'production') return;
    const android =
      (this.config.get<string[]>('links.android.fingerprints') ?? []).length > 0;
    const ios = (this.config.get<string[]>('links.ios.appIds') ?? []).length > 0;
    if (android && ios) return;
    this.logger.warn(
      'Share links will open the web page rather than the app on ' +
        [!android && 'Android', !ios && 'iOS'].filter(Boolean).join(' and ') +
        '. Set ANDROID_SHA256_CERT_FINGERPRINTS / IOS_APP_IDS once the ' +
        'signing keys and Apple team id exist.',
    );
  }
}
