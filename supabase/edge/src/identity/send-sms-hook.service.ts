import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';
import { OtpPurpose } from '@prisma/client';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { Request } from 'express';
import { normalizePhone } from '../../../../backend/src/common/phone/phone';
import { DeliveryOrchestrator } from '../../../../backend/src/modules/auth/otp/delivery.orchestrator';
import { OTP_TRANSPORTS, OtpTransport } from '../../../../backend/src/modules/auth/otp/otp-transport';
import { supabaseRuntime } from '../runtime/env';

interface SendSmsPayload {
  user?: { id?: string; phone?: string };
  sms?: { otp?: string };
}

/** Supabase's hook error envelope: it relays `message` to the client. */
function hookError(status: HttpStatus, message: string): HttpException {
  return new HttpException({ error: { http_code: status, message } }, status);
}

const TOLERANCE_SECONDS = 5 * 60;

@Injectable()
export class SendSmsHookService {
  private readonly logger = new Logger(SendSmsHookService.name);

  constructor(private readonly moduleRef: ModuleRef) {}

  async handle(req: Request & { rawBody?: Buffer }): Promise<Record<string, never>> {
    const raw = req.rawBody?.toString('utf8');
    if (!raw) throw hookError(HttpStatus.BAD_REQUEST, 'Empty hook payload');
    this.verifySignature(req, raw);

    const payload = JSON.parse(raw) as SendSmsPayload;
    const phone = payload.user?.phone ? normalizePhone(`+${payload.user.phone.replace(/^\+/, '')}`) : null;
    const code = payload.sms?.otp;
    if (!phone || !code) throw hookError(HttpStatus.BAD_REQUEST, 'Hook payload has no phone or code');

    const orchestrator = this.moduleRef.get(DeliveryOrchestrator, { strict: false });
    const transports = this.moduleRef.get<OtpTransport[]>(OTP_TRANSPORTS, { strict: false });
    const chain = await orchestrator.chain();

    for (const route of chain) {
      const transport = transports.find((candidate) => candidate.kind === route.transport);
      if (!transport?.isConfigured()) continue;

      const outcome = await transport.send({
        phone,
        code,
        // Supabase's flow has no match code on screen to compare against.
        matchCode: '--',
        purpose: OtpPurpose.LOGIN,
        expiresInMinutes: 5,
      });
      if (outcome.status === 'accepted') {
        this.logger.log(`Sign-in code for ${phone.slice(0, 6)}… handed to ${route.transport}`);
        return {};
      }
      this.logger.warn(`${route.transport} did not take the sign-in code: ${outcome.reason}`);
    }

    throw hookError(
      HttpStatus.SERVICE_UNAVAILABLE,
      'No delivery channel is configured for sign-in codes. Try again later.',
    );
  }

  /** Standard Webhooks: HMAC-SHA256 over `id.timestamp.body` with the hook secret. */
  private verifySignature(req: Request, body: string) {
    const secret = supabaseRuntime().sendSmsHookSecret;
    if (!secret) {
      this.logger.error('SEND_SMS_HOOK_SECRET is not set; refusing the Send SMS hook');
      throw hookError(HttpStatus.UNAUTHORIZED, 'Hook is not configured');
    }

    const id = req.get('webhook-id');
    const timestamp = req.get('webhook-timestamp');
    const signatures = req.get('webhook-signature');
    if (!id || !timestamp || !signatures) throw hookError(HttpStatus.UNAUTHORIZED, 'Unsigned hook');

    const age = Math.abs(Date.now() / 1000 - Number(timestamp));
    if (!Number.isFinite(age) || age > TOLERANCE_SECONDS) {
      throw hookError(HttpStatus.UNAUTHORIZED, 'Stale hook');
    }

    const key = Buffer.from(secret.replace(/^v1,/, '').replace(/^whsec_/, ''), 'base64');
    const expected = createHmac('sha256', key).update(`${id}.${timestamp}.${body}`).digest();

    const valid = signatures.split(' ').some((entry) => {
      const [version, value] = entry.split(',');
      if (version !== 'v1' || !value) return false;
      const candidate = Buffer.from(value, 'base64');
      return candidate.length === expected.length && timingSafeEqual(candidate, expected);
    });
    if (!valid) throw hookError(HttpStatus.UNAUTHORIZED, 'Bad hook signature');
  }
}
