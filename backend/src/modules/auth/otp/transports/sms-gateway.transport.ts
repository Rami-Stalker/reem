import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OtpTransportKind } from '@prisma/client';
import {
  OtpDispatch,
  OtpSendOutcome,
  OtpTransport,
  otpMessageBody,
} from '../otp-transport';

/**
 * SMS through a local Syrian aggregator.
 *
 * This is the transport the closed beta launches on, and the reason is
 * commercial rather than technical: a local aggregator contract cannot be
 * refused for sanctions reasons, whereas a WhatsApp BSP can, and SMS reaches a
 * handset that has credit but no data — which WhatsApp cannot.
 *
 * Syrian aggregators front their SMPP binds with an HTTP endpoint, and every
 * one of them shapes it differently, so the request is fully described by
 * configuration: URL, method, auth header, and a body template. Swapping
 * providers is an environment change, not a code change. If a provider ever
 * requires a real SMPP bind, it becomes a second transport class beside this
 * one rather than a rewrite of it.
 */
@Injectable()
export class SmsGatewayTransport implements OtpTransport {
  readonly kind = OtpTransportKind.SMS_GATEWAY;

  private readonly logger = new Logger(SmsGatewayTransport.name);
  private readonly endpoint?: string;
  private readonly apiKey?: string;
  private readonly sender: string;
  private readonly bodyTemplate: string;
  private readonly costMicros: number;

  constructor(config: ConfigService) {
    this.endpoint = config.get<string>('otpDelivery.sms.endpoint');
    this.apiKey = config.get<string>('otpDelivery.sms.apiKey');
    this.sender = config.get<string>('otpDelivery.sms.sender') ?? 'REEM';
    /**
     * JSON with `{{to}}`, `{{text}}`, `{{sender}}` placeholders — whatever
     * shape the contracted aggregator expects.
     */
    this.bodyTemplate =
      config.get<string>('otpDelivery.sms.bodyTemplate') ??
      '{"sender":"{{sender}}","to":"{{to}}","text":"{{text}}"}';
    this.costMicros = config.get<number>('otpDelivery.sms.costMicros') ?? 0;
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
        reason: 'SMS aggregator credentials are not configured',
      };
    }

    const text = otpMessageBody(dispatch);
    const body = this.bodyTemplate
      .replace('{{sender}}', this.escape(this.sender))
      .replace('{{to}}', this.escape(dispatch.phone))
      .replace('{{text}}', this.escape(text));

    try {
      const response = await fetch(this.endpoint as string, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body,
        signal: AbortSignal.timeout(10_000),
      });

      if (!response.ok) {
        const detail = await response.text().catch(() => '');
        return {
          status: 'failed',
          reason: `SMS gateway responded ${response.status} ${detail.slice(0, 120)}`,
        };
      }

      const payload = (await response.json().catch(() => ({}))) as {
        message_id?: string;
        id?: string;
      };

      return {
        status: 'accepted',
        providerMessageId: payload.message_id ?? payload.id,
        costMicros: this.costMicros,
        // Most local aggregators do not push delivery receipts back. Treating
        // the send as terminal stops the orchestrator waiting 25 seconds for a
        // receipt that is never coming and escalating to voice for nothing.
        terminal: true,
      };
    } catch (error) {
      this.logger.warn(
        `SMS send failed: ${error instanceof Error ? error.message : error}`,
      );
      return {
        status: 'failed',
        reason: error instanceof Error ? error.message : 'network error',
      };
    }
  }

  /** Minimal JSON string escaping for the templated body. */
  private escape(value: string): string {
    return JSON.stringify(value).slice(1, -1);
  }
}
