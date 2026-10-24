import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OtpPurpose, ReverseCeremony } from '@prisma/client';
import { SyrotpClient } from './syrotp.client';

/** What she has to do, and what settles it. */
export interface ReverseChallenge {
  ceremony: ReverseCeremony;
  /** The provider's `vrf_…` or `pbn_…` id. */
  ref: string;
  /** The receiver number the message must be addressed to. */
  sendTo: string;
  /** The exact body — `VERIFY 763PM5` or `BIND <nonce>`. */
  smsBody: string;
  expiresAt: Date;
}

export type ReverseStatus = 'pending' | 'verified' | 'unusable';

/**
 * Reverse SMS as the platform's primary proof of a phone number.
 *
 * The rail every Syrian deployment actually fights is delivery: an aggregator
 * answers "accepted" and the message never lands, and `OtpDeliveryStatus`
 * already names that gap as the dominant failure mode. No transport can fix it
 * from our side, because the loss happens downstream of every transport we
 * could contract. Reverse SMS removes the outbound leg entirely — she sends,
 * we receive — so the failure has nowhere to occur, and it needs no aggregator
 * contract, which under sanctions is the other thing that can be taken away.
 *
 * It buys one more thing. `matchCode` exists because of "this is Ohara support,
 * read me your code"; it mitigates that attack by making a recited code
 * visibly wrong. A code that travels *from* her handset cannot be recited at
 * all: an attacker wanting her number verified would have to send the message
 * from her SIM.
 *
 * What it costs is honest to state: she pays for one local SMS, she leaves the
 * app to send it, and the first number the deployment ever sees needs a
 * binding ceremony before the provider will start a verification for it.
 *
 * This service answers `null` rather than throwing whenever the provider
 * cannot be reached, which leaves the decision with the caller. Whether that
 * becomes a fallback to the transport chain or a refused request is
 * `isExclusive()`, and exclusive is the default: a deployment that has adopted
 * this rail should find out when its provider is down, not have the outage
 * papered over by an aggregator it no longer wants to depend on.
 */
@Injectable()
export class ReverseSmsService {
  private readonly logger = new Logger(ReverseSmsService.name);
  private readonly enabled: boolean;
  private readonly primary: boolean;
  private readonly exclusive: boolean;

  constructor(
    private readonly client: SyrotpClient,
    config: ConfigService,
  ) {
    this.enabled = config.get<boolean>('otpDelivery.reverse.enabled') === true;
    // Demotable to a fallback without a deployment changing code: an operator
    // who finds that fewer women finish a reverse ceremony than an SMS can put
    // the old rail back in front by setting one variable.
    this.primary = config.get<boolean>('otpDelivery.reverse.primary') !== false;
    this.exclusive =
      config.get<boolean>('otpDelivery.reverse.exclusive') !== false;
  }

  /**
   * Whether a provider outage should fail the request rather than fall back.
   *
   * True by default, because a fallback that nobody sees is a fallback nobody
   * fixes: the deployment would keep paying an aggregator to lose messages
   * occasionally, which is the thing this rail was adopted to stop. Only
   * meaningful while the rail is primary — a demoted rail has the chain in
   * front of it by definition.
   */
  isExclusive(): boolean {
    return this.isPrimary() && this.exclusive;
  }

  /** True when this rail should be tried before the transport chain. */
  isPrimary(): boolean {
    return this.enabled && this.primary && this.client.isConfigured();
  }

  isUsable(): boolean {
    return this.enabled && this.client.isConfigured();
  }

  /**
   * Opens a ceremony for `phone`, or answers `null` to mean "use another rail".
   *
   * The provider requires a `verified` phone-binding for `(app, phone)` before
   * it will start a verification, and refuses `phone_not_bound` otherwise with
   * no soft mode. So the sequence is: try the verification; on that one
   * refusal, open a binding instead and let it stand as this challenge's
   * proof. Both ceremonies are settled by a single inbound message whose
   * sender the provider checks against the claimed number, so they establish
   * the same fact, and asking her to send a second message for the same
   * assurance would be friction bought with nothing.
   */
  async start(input: {
    phone: string;
    purpose: OtpPurpose;
    challengeRef?: string;
  }): Promise<ReverseChallenge | null> {
    if (!this.isUsable()) return null;

    const started = await this.client.startVerification({
      phone: input.phone,
      purpose: `reem:${input.purpose.toLowerCase()}`,
      clientRef: input.challengeRef,
      operator: operatorHint(input.phone),
    });

    if (started.ok) {
      return this.asChallenge(
        ReverseCeremony.VERIFICATION,
        started.verification.id,
        started.verification.send_to,
        started.verification.message,
        started.verification.expires_at,
      );
    }

    if (started.kind === 'unavailable') return null;

    if (started.code === 'phone_not_bound') {
      return this.startBinding(input.phone);
    }

    throw this.refusal(started.code, started.status);
  }

  /** The first ceremony a number ever sees. */
  private async startBinding(phone: string): Promise<ReverseChallenge | null> {
    const bound = await this.client.startBinding(phone);

    if (bound.ok) {
      return this.asChallenge(
        ReverseCeremony.BINDING,
        bound.binding.binding_id,
        bound.binding.send_to,
        bound.binding.bind_message,
        bound.binding.expires_at,
      );
    }

    if (bound.kind === 'unavailable') return null;

    // `already_bound` here means the verification refused `phone_not_bound`
    // and the binding refused `already_bound` — a revoked-then-reinstated row,
    // or two requests racing. Neither is hers to understand, and both are
    // answered by the other rail.
    if (bound.code === 'already_bound' || bound.code === 'receiver_disabled') {
      this.logger.warn(
        `Reverse ceremony unavailable for this number (${bound.code}); falling back`,
      );
      return null;
    }

    throw this.refusal(bound.code, bound.status);
  }

  /**
   * Where a ceremony stands. `unusable` covers expired, cancelled, failed and
   * revoked alike: each means this challenge can no longer be settled, and the
   * caller's answer to all four is the same.
   *
   * A provider outage answers `pending`, not `unusable` — a challenge she may
   * still be able to complete must not be torn down because we could not reach
   * the provider for a moment.
   */
  async status(
    ceremony: ReverseCeremony,
    ref: string,
  ): Promise<ReverseStatus> {
    if (ceremony === ReverseCeremony.BINDING) {
      const result = await this.client.getBinding(ref);
      if (!result.ok) return result.kind === 'unavailable' ? 'pending' : 'unusable';
      if (result.binding.status === 'verified') return 'verified';
      return result.binding.status === 'pending' ? 'pending' : 'unusable';
    }

    const result = await this.client.getVerification(ref);
    if (!result.ok) return result.kind === 'unavailable' ? 'pending' : 'unusable';
    if (result.verification.status === 'verified') return 'verified';
    return result.verification.status === 'pending' ? 'pending' : 'unusable';
  }

  /** Best effort — a ceremony left pending expires on its own TTL anyway. */
  async cancel(ceremony: ReverseCeremony, ref: string): Promise<void> {
    if (ceremony !== ReverseCeremony.VERIFICATION) return;
    await this.client.cancelVerification(ref).catch(() => undefined);
  }

  private asChallenge(
    ceremony: ReverseCeremony,
    ref: string,
    sendTo: string | undefined,
    smsBody: string | undefined,
    expiresAt: string,
  ): ReverseChallenge | null {
    // The provider documents both as present while pending. If one is missing
    // the instruction would be unfollowable, and a screen telling her to send
    // "undefined" to nobody is worse than the fallback rail.
    if (!sendTo || !smsBody) {
      this.logger.warn('SYROTP start reply lacked send_to/message; falling back');
      return null;
    }
    return { ceremony, ref, sendTo, smsBody, expiresAt: new Date(expiresAt) };
  }

  /**
   * A refusal she has to be told about rather than routed around.
   *
   * The provider's pending-per-phone cap and its rate limits are abuse
   * controls. Falling through to an outbound SMS when one trips would hand an
   * abuser exactly the budget the provider just declined to give.
   */
  private refusal(code: string, status: number): HttpException {
    const tooMany = status === 429 || code === 'too_many_pending';
    // Arabic on the unavailable branch, as `cod-trust` does for the refusals a
    // customer reads: the client replaces a message with no Arabic in it by a
    // generic "try later", which would throw away the only sentence that tells
    // her this is the service's fault and not her number's.
    return new HttpException(
      tooMany
        ? { code: 'TOO_MANY_ATTEMPTS', message: 'Too many attempts' }
        : {
            code: 'OTP_UNAVAILABLE',
            message: 'خدمة التحقق غير متاحة حالياً. حاولي بعد قليل.',
          },
      tooMany ? HttpStatus.TOO_MANY_REQUESTS : HttpStatus.SERVICE_UNAVAILABLE,
    );
  }
}

/**
 * Which network a Syrian mobile number is on, as a routing hint.
 *
 * The provider prefers a healthy receiver whose operator matches and falls back
 * to any healthy receiver, so a wrong guess costs nothing and an unknown
 * prefix is better left unsent. Worth having because an on-net SMS is the
 * cheaper and more reliable of the two for her.
 */
export function operatorHint(phone: string): string | undefined {
  const digits = phone.replace(/[^\d]/g, '');
  const national = digits.startsWith('963') ? digits.slice(3) : digits.replace(/^0/, '');
  if (/^9[389]/.test(national)) return 'syriatel';
  if (/^9[456]/.test(national)) return 'mtn';
  return undefined;
}
