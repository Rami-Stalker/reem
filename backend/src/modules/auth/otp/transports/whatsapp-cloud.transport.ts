import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OtpTransportKind } from '@prisma/client';
import {
  OtpDispatch,
  OtpSendOutcome,
  OtpTransport,
} from '../otp-transport';

/**
 * WhatsApp Cloud API (Meta), the client's declared primary channel.
 *
 * Two things about this transport are specific to the market rather than to
 * Meta. First, authentication templates are the only message type that may be
 * sent to a user who has not messaged the business in the last 24 hours, so
 * the body is a template invocation, not free text — the code goes in as a
 * parameter and the wording is whatever Meta approved. Second, it needs the
 * handset to have data: a woman with credit but no data bundle, which is
 * common, is reachable by SMS and not by this. That is not a bug to fix here,
 * it is why the chain has a second link.
 *
 * Sanctions reality: Meta bills through a BSP, and a Syrian entity generally
 * cannot pay Meta directly. The credentials therefore belong to a regional
 * reseller, which is also why every field is configuration rather than a
 * constant.
 */
@Injectable()
export class WhatsAppCloudTransport implements OtpTransport {
  readonly kind = OtpTransportKind.WHATSAPP_CLOUD;

  private readonly logger = new Logger(WhatsAppCloudTransport.name);
  private readonly phoneNumberId?: string;
  private readonly accessToken?: string;
  private readonly templateName: string;
  private readonly templateLocale: string;
  private readonly apiVersion: string;
  private readonly costMicros: number;

  constructor(config: ConfigService) {
    this.phoneNumberId = config.get<string>('otpDelivery.whatsapp.phoneNumberId');
    this.accessToken = config.get<string>('otpDelivery.whatsapp.accessToken');
    this.templateName =
      config.get<string>('otpDelivery.whatsapp.template') ?? 'reem_auth_code';
    this.templateLocale =
      config.get<string>('otpDelivery.whatsapp.locale') ?? 'ar';
    this.apiVersion =
      config.get<string>('otpDelivery.whatsapp.apiVersion') ?? 'v21.0';
    this.costMicros = config.get<number>('otpDelivery.whatsapp.costMicros') ?? 0;
  }

  isConfigured(): boolean {
    return Boolean(this.phoneNumberId && this.accessToken);
  }

  reportsReceipts(): boolean {
    return true;
  }

  async send(dispatch: OtpDispatch): Promise<OtpSendOutcome> {
    if (!this.isConfigured()) {
      return {
        status: 'unavailable',
        reason: 'WhatsApp Cloud credentials are not configured',
      };
    }

    const url = `https://graph.facebook.com/${this.apiVersion}/${this.phoneNumberId}/messages`;
    const body = {
      messaging_product: 'whatsapp',
      // Meta wants the number without the leading '+'.
      to: dispatch.phone.replace(/^\+/, ''),
      type: 'template',
      template: {
        name: this.templateName,
        language: { code: this.templateLocale },
        components: [
          {
            type: 'body',
            parameters: [
              { type: 'text', text: dispatch.code },
              { type: 'text', text: dispatch.matchCode },
            ],
          },
          {
            // Authentication templates carry a one-tap copy button whose
            // parameter must repeat the code.
            type: 'button',
            sub_type: 'url',
            index: '0',
            parameters: [{ type: 'text', text: dispatch.code }],
          },
        ],
      },
    };

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(10_000),
      });

      const payload = (await response.json().catch(() => ({}))) as {
        messages?: { id: string }[];
        error?: { message?: string; code?: number };
      };

      if (!response.ok) {
        return {
          status: 'failed',
          reason:
            payload.error?.message ??
            `WhatsApp responded ${response.status}`,
        };
      }

      return {
        status: 'accepted',
        providerMessageId: payload.messages?.[0]?.id,
        costMicros: this.costMicros,
      };
    } catch (error) {
      // A timeout is a failure of this attempt, not of the challenge: the
      // orchestrator will escalate rather than strand her.
      this.logger.warn(
        `WhatsApp send failed: ${error instanceof Error ? error.message : error}`,
      );
      return {
        status: 'failed',
        reason: error instanceof Error ? error.message : 'network error',
      };
    }
  }
}
