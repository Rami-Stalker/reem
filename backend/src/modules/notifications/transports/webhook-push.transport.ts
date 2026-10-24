import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  PushBackend,
  PushDevice,
  PushDeviceOutcome,
  PushMessage,
  PushOutcome,
  summarise,
} from './push-message';

/**
 * Any push provider that speaks JSON over HTTP.
 *
 * The fallback, and deliberately kept rather than deleted when FCM arrived.
 * Google Play Services is not installed on every handset sold in Damascus —
 * Huawei devices ship without it, and an appreciable share of the market is
 * Huawei — so the day the platform contracts a second provider for those
 * phones, it is an environment change rather than a release. Shaped like the
 * SMS aggregator transport next door, for the same reason.
 *
 * FCM wins when both are configured: it is the one that can actually reach a
 * closed app on the devices most of Ohara's customers carry.
 */
@Injectable()
export class WebhookPushTransport implements PushBackend {
  readonly name = 'webhook';

  private readonly logger = new Logger(WebhookPushTransport.name);
  private readonly endpoint?: string;
  private readonly authHeader?: string;
  private readonly bodyTemplate: string;

  constructor(config: ConfigService) {
    this.endpoint = config.get<string>('push.endpoint');
    this.authHeader = config.get<string>('push.authHeader');
    /**
     * JSON with `{{token}}`, `{{title}}`, `{{body}}` and `{{deep_link}}`
     * placeholders — whatever shape the provider expects.
     */
    this.bodyTemplate =
      config.get<string>('push.bodyTemplate') ??
      '{"to":"{{token}}","notification":{"title":"{{title}}","body":"{{body}}"},"data":{"deep_link":"{{deep_link}}"}}';
  }

  isConfigured(): boolean {
    return Boolean(this.endpoint && this.authHeader);
  }

  async send(message: PushMessage): Promise<PushOutcome> {
    if (!this.isConfigured()) {
      return {
        delivered: false,
        reason: 'No push provider configured',
        devices: [],
      };
    }
    if (message.devices.length === 0) {
      return { delivered: false, reason: 'No registered device', devices: [] };
    }

    const devices = await Promise.all(
      message.devices.map((device) => this.sendOne(device, message)),
    );
    return summarise(devices);
  }

  private async sendOne(
    device: PushDevice,
    message: PushMessage,
  ): Promise<PushDeviceOutcome> {
    const body = this.bodyTemplate
      .replace(/\{\{token\}\}/g, this.escape(device.token))
      .replace(/\{\{title\}\}/g, this.escape(message.title))
      .replace(/\{\{body\}\}/g, this.escape(message.body))
      .replace(/\{\{deep_link\}\}/g, this.escape(message.deepLink ?? ''));

    try {
      const response = await fetch(this.endpoint!, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: this.authHeader!,
        },
        body,
        signal: AbortSignal.timeout(10_000),
      });

      if (!response.ok) {
        return {
          deviceId: device.id,
          ok: false,
          reason: `Push provider returned ${response.status}`,
          // A generic provider gives no machine-readable "this token is dead",
          // so 404 and 410 are the only two safe to read that way.
          invalidToken: response.status === 404 || response.status === 410,
          retryable: response.status === 429 || response.status >= 500,
        };
      }

      const payload = (await response.json().catch(() => ({}))) as {
        message_id?: string;
        name?: string;
      };
      return {
        deviceId: device.id,
        ok: true,
        providerMessageId: payload.message_id ?? payload.name,
      };
    } catch (error) {
      this.logger.warn(`Push failed: ${(error as Error).message}`);
      return {
        deviceId: device.id,
        ok: false,
        reason: (error as Error).message,
        retryable: true,
      };
    }
  }

  /** A token or a title containing a quote must not break the template. */
  private escape(value: string): string {
    return JSON.stringify(value).slice(1, -1);
  }
}
