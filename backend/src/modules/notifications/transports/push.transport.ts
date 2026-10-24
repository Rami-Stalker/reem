import { Injectable, Logger } from '@nestjs/common';
import { FcmTransport } from './fcm.transport';
import { WebhookPushTransport } from './webhook-push.transport';
import { PushBackend, PushMessage, PushOutcome } from './push-message';

export {
  PushDevice,
  PushDeviceOutcome,
  PushMessage,
  PushOutcome,
} from './push-message';

/**
 * Sending a push, or honestly saying that nothing was sent.
 *
 * The delivery worker used to mark every `PUSH` row `SENT` without anything
 * leaving the building: the platform collected device tokens, wrote a delivery
 * record, stamped it delivered, and no phone ever rang. A queue full of
 * successful deliveries nobody received is worse than an empty one, because
 * nobody goes looking.
 *
 * This is the seam that answer sits behind. Two backends live under it — FCM
 * for the phones Ohara's customers actually carry, and a generic JSON-over-HTTP
 * one for a provider contracted later — and `isConfigured()` tells the truth
 * about whether either of them can reach anything. With neither, a push is
 * recorded as skipped, never as sent.
 */
@Injectable()
export class PushTransport {
  private readonly logger = new Logger(PushTransport.name);

  constructor(
    private readonly fcm: FcmTransport,
    private readonly webhook: WebhookPushTransport,
  ) {
    const backend = this.backend();
    if (backend) {
      this.logger.log(`Push transport: ${backend.name}`);
    } else {
      // Said once, at boot, rather than discovered from an empty analytics
      // panel three weeks after launch.
      this.logger.warn(
        'No push provider configured — every push will be recorded as skipped',
      );
    }
  }

  /** True when a provider is actually contracted. */
  isConfigured(): boolean {
    return this.backend() !== undefined;
  }

  /** Which one is answering, for the delivery row's `provider` column. */
  providerName(): string {
    return this.backend()?.name ?? 'none';
  }

  async send(message: PushMessage): Promise<PushOutcome> {
    const backend = this.backend();
    if (!backend) {
      return {
        delivered: false,
        reason: 'No push provider configured',
        devices: [],
      };
    }
    if (message.devices.length === 0) {
      return { delivered: false, reason: 'No registered device', devices: [] };
    }
    return backend.send(message);
  }

  /** FCM first: it is the one that reaches a closed app on most handsets. */
  private backend(): PushBackend | undefined {
    if (this.fcm.isConfigured()) return this.fcm;
    if (this.webhook.isConfigured()) return this.webhook;
    return undefined;
  }
}
