import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * The SYROTP REST surface, and nothing else.
 *
 * SYROTP is a self-hosted reverse-OTP service: it mints a code, she sends it
 * from her own handset to a receiver number the deployment owns, and an
 * Android phone or GSM modem forwards the inbound message to the server, which
 * checks that the sender is the number that was claimed. The platform never
 * sends anything outbound, which is the whole point — see
 * `reverse-sms.service.ts` for why that matters here.
 *
 * This class speaks HTTP and keeps opinions out. It does not decide which
 * ceremony to run, does not fall back, and does not retry: those are policy,
 * and policy lives one layer up where it can be read in one place.
 *
 * Two deliberate shapes:
 *
 *  - Everything is `sk_live_` (secret key) rather than `pk_live_`. The public
 *    key exists for browser-embedded callers and is explicitly not
 *    origin-bound in the provider's threat model, so it has no business in a
 *    backend that already holds the secret.
 *  - A transport failure is a *typed value*, not an exception. The caller has
 *    a second rail to fall through to, and an outage of this one must not
 *    become a failed sign-in.
 */

/** A provider reply that arrived and was understood. */
export interface SyrotpVerification {
  id: string;
  status: 'pending' | 'verified' | 'expired' | 'cancelled' | 'failed';
  /** Present on the start reply only, while pending. */
  send_to?: string;
  /** The exact body she must send; matching is trimmed and case-insensitive. */
  message?: string;
  expires_at: string;
  attempts?: number;
}

export interface SyrotpBinding {
  binding_id: string;
  phone_e164: string;
  status: 'pending' | 'verified' | 'revoked';
  expires_at: string;
  send_to: string;
  /** `BIND <nonce>` — a single-use bearer token. Never logged. */
  bind_message: string;
}

export interface SyrotpBindingState {
  id: string;
  status: 'pending' | 'verified' | 'revoked';
  expires_at: string;
}

/**
 * Why a call did not produce an answer.
 *
 *  - `unavailable` — the provider could not be reached, or answered 5xx. The
 *    caller should use another rail; nothing was decided.
 *  - `rejected` — the provider understood and refused, and `code` says why.
 *    A refusal is a decision and must not be laundered by retrying elsewhere:
 *    `too_many_pending` falling through to an outbound SMS would hand an
 *    abuser the cap the provider just enforced.
 */
export type SyrotpFailure =
  | { ok: false; kind: 'unavailable'; reason: string }
  | { ok: false; kind: 'rejected'; status: number; code: string; reason: string };

export type SyrotpResult<T> = ({ ok: true } & T) | SyrotpFailure;

@Injectable()
export class SyrotpClient {
  private readonly logger = new Logger(SyrotpClient.name);
  private readonly baseUrl?: string;
  private readonly secretKey?: string;
  private readonly receiverId?: string;
  private readonly timeoutMs: number;

  constructor(config: ConfigService) {
    this.baseUrl = config
      .get<string>('otpDelivery.reverse.baseUrl')
      ?.replace(/\/+$/, '');
    this.secretKey = config.get<string>('otpDelivery.reverse.secretKey');
    this.receiverId = config.get<string>('otpDelivery.reverse.receiverId');
    this.timeoutMs = config.get<number>('otpDelivery.reverse.timeoutMs') ?? 8_000;
  }

  isConfigured(): boolean {
    return Boolean(this.baseUrl && this.secretKey && this.receiverId);
  }

  /** Liveness only — says nothing about whether a receiver is healthy. */
  async health(): Promise<boolean> {
    const result = await this.call<{ status: string }>('GET', '/v1/health', {
      authenticated: false,
    });
    return result.ok && result.body.status === 'ok';
  }

  async startVerification(input: {
    phone: string;
    purpose: string;
    clientRef?: string;
    operator?: string;
  }): Promise<SyrotpResult<{ verification: SyrotpVerification }>> {
    const result = await this.call<SyrotpVerification>(
      'POST',
      '/v1/verifications',
      {
        body: {
          phone: input.phone,
          purpose: input.purpose,
          client_ref: input.clientRef,
          operator: input.operator,
        },
      },
    );
    return result.ok ? { ok: true, verification: result.body } : result;
  }

  async getVerification(
    id: string,
  ): Promise<SyrotpResult<{ verification: SyrotpVerification }>> {
    const result = await this.call<SyrotpVerification>(
      'GET',
      `/v1/verifications/${encodeURIComponent(id)}`,
    );
    return result.ok ? { ok: true, verification: result.body } : result;
  }

  async cancelVerification(id: string): Promise<void> {
    await this.call('POST', `/v1/verifications/${encodeURIComponent(id)}/cancel`);
  }

  async startBinding(
    phone: string,
  ): Promise<SyrotpResult<{ binding: SyrotpBinding }>> {
    const result = await this.call<SyrotpBinding>(
      'POST',
      '/v1/phone-bindings/start',
      { body: { phone, receiver_id: this.receiverId } },
    );
    return result.ok ? { ok: true, binding: result.body } : result;
  }

  async getBinding(
    id: string,
  ): Promise<SyrotpResult<{ binding: SyrotpBindingState }>> {
    const result = await this.call<SyrotpBindingState>(
      'GET',
      `/v1/phone-bindings/${encodeURIComponent(id)}`,
    );
    return result.ok ? { ok: true, binding: result.body } : result;
  }

  /**
   * One request, with the provider's error envelope decoded.
   *
   * Nothing from a response body reaches a log except the provider's own
   * `code` and `request_id`: a start reply carries `bind_message`, which is a
   * single-use credential, and the provider's own documentation says to keep
   * it out of structured logs.
   */
  private async call<T>(
    method: 'GET' | 'POST',
    path: string,
    options: { body?: unknown; authenticated?: boolean } = {},
  ): Promise<({ ok: true; body: T }) | SyrotpFailure> {
    if (!this.isConfigured()) {
      return { ok: false, kind: 'unavailable', reason: 'syrotp_not_configured' };
    }

    let response: Response;
    try {
      response = await fetch(`${this.baseUrl}${path}`, {
        method,
        headers: {
          ...(options.authenticated === false
            ? {}
            : { authorization: `Bearer ${this.secretKey}` }),
          ...(options.body ? { 'content-type': 'application/json' } : {}),
        },
        body: options.body ? JSON.stringify(options.body) : undefined,
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (error) {
      const reason = error instanceof Error ? error.name : 'network_error';
      this.logger.warn(`SYROTP ${method} ${path} unreachable (${reason})`);
      return { ok: false, kind: 'unavailable', reason };
    }

    // Success bodies are the resource itself; failures are
    // `{ error: { code, message, request_id } }`. Reading the code from the
    // top level instead would turn every refusal into an opaque `http_403`,
    // and `phone_not_bound` is the one refusal the caller must recognise.
    const payload = (await response.json().catch(() => null)) as
      | (T & {
          error?: { code?: string; message?: string; request_id?: string };
        })
      | null;

    if (response.ok) {
      if (!payload) {
        return { ok: false, kind: 'unavailable', reason: 'unparseable_body' };
      }
      return { ok: true, body: payload };
    }

    // 5xx and 503 are the provider having a bad day; the caller may use
    // another rail. A 4xx is the provider's considered answer and is not
    // something a second rail should be asked to overrule.
    if (response.status >= 500) {
      this.logger.warn(`SYROTP ${method} ${path} -> ${response.status}`);
      return { ok: false, kind: 'unavailable', reason: `http_${response.status}` };
    }

    const code = payload?.error?.code ?? `http_${response.status}`;
    this.logger.warn(
      `SYROTP ${method} ${path} refused: ${code}` +
        (payload?.error?.request_id
          ? ` (request ${payload.error.request_id})`
          : ''),
    );
    return {
      ok: false,
      kind: 'rejected',
      status: response.status,
      code,
      reason: code,
    };
  }
}
