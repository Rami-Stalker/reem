import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OtpTransportKind } from '@prisma/client';
import { OtpDispatch, OtpSendOutcome, OtpTransport } from '../otp-transport';

/**
 * A robot call that reads the digits out.
 *
 * The last automated link in the chain, and the one that works when the others
 * cannot: no data bundle, an SMS route congested or filtered, a number that
 * has never been on WhatsApp. It is also the most expensive per delivery,
 * which is exactly why it sits last and behind a budget breaker.
 *
 * Accessibility is a real second reason to keep it: a voice call is the only
 * channel in this chain that works for a user who cannot read the message.
 */
@Injectable()
export class VoiceTransport implements OtpTransport {
  readonly kind = OtpTransportKind.VOICE;

  private readonly logger = new Logger(VoiceTransport.name);
  private readonly endpoint?: string;
  private readonly apiKey?: string;
  private readonly costMicros: number;

  constructor(config: ConfigService) {
    this.endpoint = config.get<string>('otpDelivery.voice.endpoint');
    this.apiKey = config.get<string>('otpDelivery.voice.apiKey');
    this.costMicros = config.get<number>('otpDelivery.voice.costMicros') ?? 0;
  }

  isConfigured(): boolean {
    return Boolean(this.endpoint && this.apiKey);
  }

  reportsReceipts(): boolean {
    return false;
  }

  async send(dispatch: OtpDispatch): Promise<OtpSendOutcome> {
    if (!this.isConfigured()) {
      return {
        status: 'unavailable',
        reason: 'Voice provider is not configured',
      };
    }

    // Digits are spaced so the text-to-speech engine reads them one by one
    // rather than as a number in the thousands.
    const spoken = dispatch.code.split('').join(' ');

    try {
      const response = await fetch(this.endpoint as string, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: dispatch.phone,
          locale: 'ar',
          // Repeated because a caller who missed the first reading has no way
          // to ask for it again.
          text: `رمز ريم الخاص بك هو ${spoken}. أكرر: ${spoken}.`,
        }),
        signal: AbortSignal.timeout(15_000),
      });

      if (!response.ok) {
        return {
          status: 'failed',
          reason: `Voice provider responded ${response.status}`,
        };
      }

      const payload = (await response.json().catch(() => ({}))) as {
        call_id?: string;
      };

      return {
        status: 'accepted',
        providerMessageId: payload.call_id,
        costMicros: this.costMicros,
        terminal: true,
      };
    } catch (error) {
      this.logger.warn(
        `Voice call failed: ${error instanceof Error ? error.message : error}`,
      );
      return {
        status: 'failed',
        reason: error instanceof Error ? error.message : 'network error',
      };
    }
  }
}
