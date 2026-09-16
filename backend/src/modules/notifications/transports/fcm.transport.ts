import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createSign } from 'crypto';
import {
  PushBackend,
  PushDevice,
  PushDeviceOutcome,
  PushMessage,
  PushOutcome,
  summarise,
} from './push-message';

/** Google's OAuth2 endpoint and the one scope a sender needs. */
const TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const JWT_BEARER = 'urn:ietf:params:oauth:grant-type:jwt-bearer';

/** A service-account key, in the three fields of it that matter. */
interface ServiceAccount {
  readonly projectId: string;
  readonly clientEmail: string;
  readonly privateKey: string;
}

/**
 * Firebase Cloud Messaging, HTTP v1.
 *
 * This is the transport that makes a notification arrive on a phone whose
 * owner has closed the app, which is the only kind of notification that
 * really matters — an in-app row is a record of something she was never told.
 *
 * ## Why v1 and not the endpoint that was here
 *
 * The previous transport posted to `fcm.googleapis.com/fcm/send` with a
 * server key in an `Authorization: key=` header. Google decommissioned that
 * API in June 2024; it answers 404 to everything. So the configuration it
 * described could be filled in correctly and completely and still never ring
 * a phone — the worst kind of integration, because it looks contracted.
 *
 * v1 costs one thing the legacy API did not: the credential is a service
 * account rather than a static key, so every request carries a short-lived
 * OAuth2 access token minted from a signed assertion. That is the second half
 * of this file. It is done with Node's own `crypto` rather than
 * `google-auth-library` because the whole of it is ninety lines and the
 * alternative is a transitive dependency tree larger than this module.
 *
 * ## Why the envelope is shaped the way it is
 *
 * Getting a push to appear on a locked, dozing phone is mostly about four
 * fields, and every one of them is easy to leave out:
 *
 *  - **`android.priority: HIGH`** is the only thing that wakes a device in
 *    Doze. Normal priority is delivered "at some point", which in practice
 *    means when she next unlocks — by which time she has opened the app.
 *  - **`apns.headers.apns-priority: 10`** with `apns-push-type: alert`. iOS
 *    refuses, silently, to display an alert pushed at priority 5, and since
 *    iOS 13 rejects outright a push carrying no `apns-push-type`.
 *  - **`android.notification.channel_id`**. Android 8 and later drops a
 *    notification naming a channel that does not exist on the device, so the
 *    names here and the channels the client creates at startup have to agree.
 *    They are one shared constant rather than two string literals for exactly
 *    that reason.
 *  - **`data` alongside `notification`** — the tap routing. A `notification`
 *    block on its own is drawn by the operating system and hands the app
 *    nothing to act on when she taps it.
 *
 * ## Configuration
 *
 * Either `FCM_SERVICE_ACCOUNT_JSON` (the downloaded key file, raw or base64)
 * or the three fields separately. Nothing set means not configured, and the
 * delivery worker records a skip rather than claiming a send.
 */
@Injectable()
export class FcmTransport implements PushBackend {
  readonly name = 'fcm';

  private readonly logger = new Logger(FcmTransport.name);
  private readonly account?: ServiceAccount;
  private readonly endpoint?: string;

  /** The current access token, and the instant it stops being usable. */
  private accessToken?: { value: string; expiresAt: number };
  /** In flight, so a burst of sends mints one token rather than fifty. */
  private tokenRequest?: Promise<string | undefined>;

  constructor(config: ConfigService) {
    this.account = FcmTransport.readAccount(config);
    this.endpoint = this.account
      ? `https://fcm.googleapis.com/v1/projects/${this.account.projectId}/messages:send`
      : undefined;
  }

  isConfigured(): boolean {
    return Boolean(this.account);
  }

  async send(message: PushMessage): Promise<PushOutcome> {
    if (!this.isConfigured()) {
      return { delivered: false, reason: 'FCM is not configured', devices: [] };
    }
    if (message.devices.length === 0) {
      return { delivered: false, reason: 'No registered device', devices: [] };
    }

    const accessToken = await this.authorize();
    if (!accessToken) {
      return {
        delivered: false,
        reason: 'Could not mint an FCM access token',
        // The credential may be fine and Google merely unreachable, so this is
        // worth another attempt rather than a permanent failure.
        retryable: true,
        devices: [],
      };
    }

    // One request per handset. A woman with a phone and a tablet has two, and
    // a provider that refuses one must not lose the other.
    const devices = await Promise.all(
      message.devices.map((device) =>
        this.sendOne(device, message, accessToken),
      ),
    );
    return summarise(devices);
  }

  // -- The envelope --------------------------------------------------------

  /**
   * Builds the v1 message for one device.
   *
   * Split out and reachable from the tests because this is the part that is
   * wrong in every push integration that "works in the foreground only", and
   * a unit test over a plain object is the only way to see it without a
   * handset in your hand.
   */
  buildMessage(device: PushDevice, message: PushMessage): unknown {
    const data = FcmTransport.stringifyData({
      ...(message.data ?? {}),
      ...(message.deepLink ? { deep_link: message.deepLink } : {}),
      ...(message.channelId ? { channel_id: message.channelId } : {}),
      // So a foreground handler can render the same sentence the OS would
      // have drawn, rather than having to guess it from the data.
      title: message.title,
      body: message.body,
    });

    const urgent = message.urgent ?? true;
    const platform = (device.platform ?? '').toLowerCase();

    return {
      message: {
        token: device.token,
        notification: { title: message.title, body: message.body },
        data,
        ...(platform === 'ios' ? {} : { android: this.android(message, urgent) }),
        ...(platform === 'android' ? {} : { apns: this.apns(message, urgent) }),
      },
    };
  }

  private android(message: PushMessage, urgent: boolean) {
    return {
      priority: urgent ? 'HIGH' : 'NORMAL',
      ...(message.collapseKey ? { collapse_key: message.collapseKey } : {}),
      ...(message.ttlSeconds ? { ttl: `${message.ttlSeconds}s` } : {}),
      notification: {
        // Must name a channel the client has created, or Android 8+ drops it.
        ...(message.channelId ? { channel_id: message.channelId } : {}),
        // Same tag means replace in the shade rather than stack. This is what
        // keeps twelve likes on one post from being twelve lines.
        ...(message.collapseKey ? { tag: message.collapseKey } : {}),
        sound: 'default',
        default_vibrate_timings: true,
        ...(message.badge !== undefined
          ? { notification_count: message.badge }
          : {}),
      },
    };
  }

  private apns(message: PushMessage, urgent: boolean) {
    return {
      headers: {
        // 10 displays immediately; 5 is "at the system's convenience", which
        // for a closed app can mean not at all.
        'apns-priority': urgent ? '10' : '5',
        // Required since iOS 13. A push without it is rejected by APNs.
        'apns-push-type': 'alert',
        ...(message.ttlSeconds
          ? {
              'apns-expiration': String(
                Math.floor(Date.now() / 1000) + message.ttlSeconds,
              ),
            }
          : {}),
        ...(message.collapseKey
          ? { 'apns-collapse-id': message.collapseKey.slice(0, 64) }
          : {}),
      },
      payload: {
        aps: {
          alert: { title: message.title, body: message.body },
          sound: 'default',
          ...(message.badge !== undefined ? { badge: message.badge } : {}),
          // Stacks by conversation or order rather than by app.
          ...(message.collapseKey ? { 'thread-id': message.collapseKey } : {}),
          // Lets a notification-service extension decorate it before it is
          // drawn. Harmless when no extension is installed.
          'mutable-content': 1,
        },
      },
    };
  }

  /** FCM's `data` map is string to string, and rejects the request otherwise. */
  private static stringifyData(
    data: Record<string, unknown>,
  ): Record<string, string> {
    const out: Record<string, string> = {};
    for (const [key, value] of Object.entries(data)) {
      if (value === undefined || value === null) continue;
      out[key] = typeof value === 'string' ? value : JSON.stringify(value);
    }
    return out;
  }

  // -- One request ---------------------------------------------------------

  private async sendOne(
    device: PushDevice,
    message: PushMessage,
    accessToken: string,
  ): Promise<PushDeviceOutcome> {
    try {
      const response = await fetch(this.endpoint!, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(this.buildMessage(device, message)),
        signal: AbortSignal.timeout(10_000),
      });

      if (response.ok) {
        const payload = (await response.json().catch(() => ({}))) as {
          name?: string;
        };
        return {
          deviceId: device.id,
          ok: true,
          providerMessageId: payload.name,
        };
      }

      const text = await response.text().catch(() => '');
      const classified = FcmTransport.classify(response.status, text);
      // Our credential expired mid-flight or was revoked; drop it so the next
      // attempt mints a fresh one rather than replaying the same refusal.
      if (response.status === 401) this.accessToken = undefined;
      return { deviceId: device.id, ok: false, ...classified };
    } catch (error) {
      // A push that could not be sent is not an error worth failing an order
      // over; it is a line in the log and a delivery row that gets retried.
      const reason = (error as Error).message;
      this.logger.warn(`FCM send failed: ${reason}`);
      return { deviceId: device.id, ok: false, reason, retryable: true };
    }
  }

  /**
   * What FCM's refusal means for this token.
   *
   * The distinction earns its keep twice over. A dead token retried on a
   * backoff is a request that can never succeed, repeated for ever; and a
   * transient 503 read as a dead token silently unsubscribes a woman from
   * every future notification because Google had a bad minute.
   */
  static classify(
    status: number,
    body: string,
  ): { reason: string; invalidToken?: boolean; retryable?: boolean } {
    const errorCode = /"errorCode"\s*:\s*"([A-Z_]+)"/.exec(body)?.[1];
    const reason = errorCode
      ? `FCM ${status} ${errorCode}`
      : `FCM returned ${status}`;

    // The app was uninstalled, or the token was rotated out from under us.
    if (errorCode === 'UNREGISTERED' || status === 404) {
      return { reason, invalidToken: true };
    }
    // The token belongs to a different Firebase project. The configuration is
    // what is wrong, but the token is unusable here either way.
    if (errorCode === 'SENDER_ID_MISMATCH') {
      return { reason, invalidToken: true };
    }
    // A malformed token. Also how FCM answers a genuinely malformed envelope,
    // which is why the message builder has tests: the two look alike here.
    if (status === 400) {
      return { reason, invalidToken: true };
    }
    // Our own credential, not her device.
    if (status === 401 || status === 403) {
      return { reason, retryable: true };
    }
    // Rate limited, or Google is having a moment.
    if (status === 429 || status >= 500) {
      return { reason, retryable: true };
    }
    return { reason };
  }

  // -- The credential ------------------------------------------------------

  /**
   * A usable access token, minted or remembered.
   *
   * Tokens last an hour; this treats them as expiring five minutes early so a
   * send never loses a race with the clock, and single-flights the mint so a
   * campaign fanning out to six hundred women asks Google once.
   */
  private async authorize(): Promise<string | undefined> {
    const cached = this.accessToken;
    if (cached && cached.expiresAt > Date.now()) return cached.value;
    if (this.tokenRequest) return this.tokenRequest;

    this.tokenRequest = this.mintToken().finally(() => {
      this.tokenRequest = undefined;
    });
    return this.tokenRequest;
  }

  private async mintToken(): Promise<string | undefined> {
    const account = this.account!;
    const now = Math.floor(Date.now() / 1000);
    const assertion = FcmTransport.signJwt(
      {
        iss: account.clientEmail,
        scope: SCOPE,
        aud: TOKEN_ENDPOINT,
        iat: now,
        exp: now + 3600,
      },
      account.privateKey,
    );
    if (!assertion) return undefined;

    try {
      const response = await fetch(TOKEN_ENDPOINT, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: JWT_BEARER,
          assertion,
        }).toString(),
        signal: AbortSignal.timeout(10_000),
      });

      if (!response.ok) {
        const detail = await response.text().catch(() => '');
        this.logger.error(
          `FCM token request failed: ${response.status} ${detail}`,
        );
        return undefined;
      }

      const payload = (await response.json()) as {
        access_token?: string;
        expires_in?: number;
      };
      if (!payload.access_token) return undefined;

      this.accessToken = {
        value: payload.access_token,
        expiresAt: Date.now() + ((payload.expires_in ?? 3600) - 300) * 1000,
      };
      return payload.access_token;
    } catch (error) {
      this.logger.error(`FCM token request threw: ${(error as Error).message}`);
      return undefined;
    }
  }

  /** RS256, by hand. The whole of what `google-auth-library` would be for. */
  private static signJwt(
    claims: Record<string, string | number>,
    privateKey: string,
  ): string | undefined {
    try {
      const encode = (value: unknown) =>
        Buffer.from(JSON.stringify(value)).toString('base64url');
      const unsigned = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode(claims)}`;
      const signature = createSign('RSA-SHA256')
        .update(unsigned)
        .sign(privateKey)
        .toString('base64url');
      return `${unsigned}.${signature}`;
    } catch (error) {
      // Almost always a private key that lost its newlines on the way through
      // a dashboard's environment editor. Say so here rather than at send.
      new Logger(FcmTransport.name).error(
        `FCM private key is unusable: ${(error as Error).message}`,
      );
      return undefined;
    }
  }

  /**
   * Reads the service account out of configuration.
   *
   * Two spellings, because the two places this runs disagree about what an
   * environment variable may hold. A JSON key file pasted into Render's editor
   * survives; the same file base64'd survives a shell. And the three-field
   * form exists because `FCM_PRIVATE_KEY` is routinely pasted with literal
   * `\n` in it, which is normalised here rather than in six places.
   */
  private static readAccount(config: ConfigService): ServiceAccount | undefined {
    const raw = config.get<string>('push.fcm.serviceAccount');
    if (raw && raw.trim()) {
      const parsed = FcmTransport.parseServiceAccount(raw.trim());
      if (parsed) return parsed;
    }

    const projectId = config.get<string>('push.fcm.projectId');
    const clientEmail = config.get<string>('push.fcm.clientEmail');
    const privateKey = config.get<string>('push.fcm.privateKey');
    if (!projectId || !clientEmail || !privateKey) return undefined;

    return {
      projectId,
      clientEmail,
      privateKey: FcmTransport.normaliseKey(privateKey),
    };
  }

  private static parseServiceAccount(raw: string): ServiceAccount | undefined {
    const json = raw.startsWith('{')
      ? raw
      : Buffer.from(raw, 'base64').toString('utf8');
    try {
      const parsed = JSON.parse(json) as {
        project_id?: string;
        client_email?: string;
        private_key?: string;
      };
      if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
        return undefined;
      }
      return {
        projectId: parsed.project_id,
        clientEmail: parsed.client_email,
        privateKey: FcmTransport.normaliseKey(parsed.private_key),
      };
    } catch {
      new Logger(FcmTransport.name).error(
        'FCM_SERVICE_ACCOUNT_JSON is not valid JSON — push is disabled',
      );
      return undefined;
    }
  }

  /** `\n` written literally is the commonest way this credential is broken. */
  private static normaliseKey(key: string): string {
    return key.includes('\\n') ? key.replace(/\\n/g, '\n') : key;
  }
}
