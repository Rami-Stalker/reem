import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/** One push, addressed to the handsets of one account. */
export interface PushMessage {
  readonly tokens: readonly string[];
  readonly title: string;
  readonly body: string;
  readonly data?: Record<string, string>;
}

export interface PushOutcome {
  readonly delivered: boolean;
  /** Why not, when not — recorded on the delivery row rather than swallowed. */
  readonly reason?: string;
  readonly providerMessageId?: string;
}

/**
 * Sending a push, or honestly saying that nothing was sent.
 *
 * The delivery worker used to mark every `PUSH` row `SENT` without anything
 * leaving the building: the platform collected device tokens, wrote a delivery
 * record, stamped it delivered, and no phone ever rang. A queue full of
 * successful deliveries nobody received is worse than an empty one, because
 * nobody goes looking.
 *
 * Shaped like the SMS aggregator transport next door and for the same reason:
 * the provider is described by configuration, so contracting one is an
 * environment change rather than a release.
 */
@Injectable()
export class PushTransport {
  private readonly logger = new Logger(PushTransport.name);
  private readonly endpoint?: string;
  private readonly authHeader?: string;
  private readonly bodyTemplate: string;

  constructor(config: ConfigService) {
    this.endpoint = config.get<string>('push.endpoint');
    this.authHeader = config.get<string>('push.authHeader');
    /**
     * JSON with `{{token}}`, `{{title}}`, `{{body}}` placeholders — whatever
     * shape the provider expects. The default is Firebase's legacy `/fcm/send`
     * body, which is the one most Syrian-market SDKs still target.
     */
    this.bodyTemplate =
      config.get<string>('push.bodyTemplate') ??
      '{"to":"{{token}}","notification":{"title":"{{title}}","body":"{{body}}"}}';
  }

  /**
   * True when a provider is actually contracted.
   *
   * The delivery worker asks this *before* claiming anything: with no
   * provider a push is recorded as skipped, never as sent.
   */
  isConfigured(): boolean {
    return Boolean(this.endpoint && this.authHeader);
  }

  async send(message: PushMessage): Promise<PushOutcome> {
    if (!this.isConfigured()) {
      return {
        delivered: false,
        reason: 'No push provider configured',
      };
    }
    if (message.tokens.length === 0) {
      return { delivered: false, reason: 'No registered device' };
    }

    // One request per handset. A woman with a phone and a tablet has two, and
    // a provider that fails for one must not lose the other.
    const results = await Promise.all(
      message.tokens.map((token) => this.sendOne(token, message)),
    );

    const delivered = results.filter((result) => result.ok);
    if (delivered.length === 0) {
      return {
        delivered: false,
        reason: results[0]?.reason ?? 'Push provider refused every device',
      };
    }

    return {
      delivered: true,
      providerMessageId: delivered[0].id,
      // Partial success is still success for the customer — she got it on the
      // phone in her hand — but the failures are worth a line in the log.
      reason:
        delivered.length === results.length
          ? undefined
          : `${results.length - delivered.length} of ${results.length} devices failed`,
    };
  }

  private async sendOne(
    token: string,
    message: PushMessage,
  ): Promise<{ ok: boolean; id?: string; reason?: string }> {
    const body = this.bodyTemplate
      .replace(/\{\{token\}\}/g, this.escape(token))
      .replace(/\{\{title\}\}/g, this.escape(message.title))
      .replace(/\{\{body\}\}/g, this.escape(message.body));

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
          ok: false,
          reason: `Push provider returned ${response.status}`,
        };
      }

      const payload = (await response.json().catch(() => ({}))) as {
        message_id?: string;
        name?: string;
      };
      return { ok: true, id: payload.message_id ?? payload.name };
    } catch (error) {
      // A push that could not be sent is not an error worth failing an order
      // over; it is a line in the log and a failed delivery row.
      this.logger.warn(`Push failed: ${(error as Error).message}`);
      return { ok: false, reason: (error as Error).message };
    }
  }

  /** A token or a title containing a quote must not break the template. */
  private escape(value: string): string {
    return JSON.stringify(value).slice(1, -1);
  }
}
