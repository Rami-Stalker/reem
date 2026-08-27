import { OtpPurpose, OtpTransportKind } from '@prisma/client';

/** What a transport is asked to deliver. */
export interface OtpDispatch {
  /** Canonical E.164 destination. */
  phone: string;
  /** The plaintext one-time code. Never logged, never persisted unsealed. */
  code: string;
  /**
   * Two digits also shown on the screen that asked for the code. Carried in
   * the message so she can tell a code she requested from a code somebody is
   * reading to her over the phone.
   */
  matchCode: string;
  purpose: OtpPurpose;
  /** Minutes until the code expires, for the message copy. */
  expiresInMinutes: number;
}

export type OtpSendOutcome =
  /** The provider accepted the message. Delivery is not yet confirmed. */
  | {
      status: 'accepted';
      providerMessageId?: string;
      costMicros: number;
      /** True when the transport can never produce a delivery receipt. */
      terminal?: boolean;
      /**
       * Keep the sealed code readable after the send. Only the ops-console
       * "transport" needs this: the delivery is a human reading the code out
       * of the admin screen, so shredding it on accept would destroy the very
       * thing that has to be read.
       */
      retainCode?: boolean;
      metadata?: Record<string, unknown>;
    }
  /** The provider rejected it, or the transport is not usable right now. */
  | { status: 'failed'; reason: string; costMicros?: number }
  /** Not configured / disabled — the orchestrator moves on without penalty. */
  | { status: 'unavailable'; reason: string };

/**
 * A way of getting six digits onto a handset in Syria.
 *
 * Transports are deliberately dumb: they do not retry, do not choose the next
 * channel and do not know about budgets. All of that is the orchestrator's
 * job, so adding a provider is one class and one row in `otp_transport_routes`.
 */
export interface OtpTransport {
  readonly kind: OtpTransportKind;

  /** False when credentials are missing — the chain then skips it silently. */
  isConfigured(): boolean;

  /**
   * Whether this channel ever confirms arrival on the handset.
   *
   * Only WhatsApp does. Reporting a delivery *rate* for a channel that cannot
   * report delivery would show a perfectly healthy SMS gateway as a 0% channel
   * and invite someone to switch it off — so the report shows "no data"
   * instead, and the report is what decides the primary channel in week one.
   */
  reportsReceipts(): boolean;

  send(dispatch: OtpDispatch): Promise<OtpSendOutcome>;
}

export const OTP_TRANSPORTS = Symbol('OTP_TRANSPORTS');

/**
 * Arabic message copy, addressed in the feminine per the client's locked
 * requirement. Kept beside the transports because every one of them sends the
 * same sentence — only the envelope differs.
 */
export function otpMessageBody(dispatch: OtpDispatch): string {
  const purposeLine =
    dispatch.purpose === OtpPurpose.PASSWORD_RESET
      ? 'رمز إعادة تعيين كلمة المرور'
      : dispatch.purpose === OtpPurpose.DEVICE_VERIFICATION
        ? 'رمز تأكيد الجهاز'
        : 'رمز تفعيل حسابكِ';

  return [
    `${purposeLine} في ريم: ${dispatch.code}`,
    `رمز المطابقة: ${dispatch.matchCode}`,
    `ينتهي خلال ${dispatch.expiresInMinutes} دقائق.`,
    'لا تشاركي هذا الرمز مع أحد، ولن يطلبه منك فريق ريم أبداً.',
  ].join('\n');
}

/** `+963912345678` → `+9639****5678`, for showing her where it went. */
export function maskDestination(phone: string): string {
  if (phone.length <= 8) return phone;
  return `${phone.slice(0, 5)}****${phone.slice(-4)}`;
}
