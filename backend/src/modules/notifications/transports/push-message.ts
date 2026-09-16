/**
 * What a push is, and what happened to it — shared by every backend.
 *
 * Two shapes rather than one because the delivery worker needs both answers:
 * "did she get it" decides the delivery row's status, and "which of her
 * handsets is gone" decides whether a token stays in the table. The second
 * answer used to be thrown away, which is how a push table fills with the
 * addresses of uninstalled apps and every send starts costing four requests
 * to reach one phone.
 */

/** One handset, addressed. */
export interface PushDevice {
  readonly id: string;
  readonly token: string;
  /** `android`, `ios`, `web` — decides which half of the envelope is filled. */
  readonly platform?: string | null;
}

/**
 * One push, addressed to the handsets of one account.
 *
 * `data` is the half that survives everything. A `notification` block is drawn
 * by the operating system and its payload is *not* handed to the app when the
 * woman taps it on iOS unless it is accompanied by data — so the routing
 * information lives in `data`, always, and the visible sentence lives in
 * `notification`, always. Splitting them the other way around is the classic
 * way to ship a push that shows up and then opens the home screen.
 */
export interface PushMessage {
  readonly devices: readonly PushDevice[];
  readonly title: string;
  readonly body: string;
  /** Route to open on tap — `reem://orders/<id>`. Travels in `data`. */
  readonly deepLink?: string;
  /** Everything else the client may want; stringified, because FCM demands it. */
  readonly data?: Record<string, string>;
  /**
   * Which drawer on the phone this belongs in. Android calls it a channel and
   * refuses to show a heads-up notification without one that exists; iOS calls
   * it a thread and uses it to stack. Same string, both jobs.
   */
  readonly channelId?: string;
  /**
   * Replaces rather than stacks. Four "someone liked your post" in an evening
   * should be one line on the lock screen, not four — so likes on the same
   * post collapse onto each other.
   */
  readonly collapseKey?: string;
  /** The number on the app icon. Her unread count, not this message's index. */
  readonly badge?: number;
  /**
   * How long the provider should keep trying, in seconds.
   *
   * A chat message is worth an hour; after that she has opened the app and
   * read it, and a push about it is noise. An order that has shipped is worth
   * a day. Nothing is worth FCM's four-week default.
   */
  readonly ttlSeconds?: number;
  /**
   * Whether this wakes a sleeping phone.
   *
   * High priority is what actually delivers to a device in Doze, which is the
   * state every phone is in at the moment this matters — the app is closed and
   * the screen is off. It is also the thing Android meters: a sender that
   * marks everything urgent gets deprioritised, so promotions do not.
   */
  readonly urgent?: boolean;
}

/** What one handset did with it. */
export interface PushDeviceOutcome {
  readonly deviceId: string;
  readonly ok: boolean;
  readonly providerMessageId?: string;
  readonly reason?: string;
  /**
   * The provider says this address is dead — the app was uninstalled, or the
   * token was reissued. The token is disabled rather than retried; there is
   * nothing at the other end and never will be again.
   */
  readonly invalidToken?: boolean;
  /**
   * The provider was busy or broken. Worth trying again on a backoff; a
   * refusal is not.
   */
  readonly retryable?: boolean;
}

export interface PushOutcome {
  readonly delivered: boolean;
  /** Why not, when not — recorded on the delivery row rather than swallowed. */
  readonly reason?: string;
  readonly providerMessageId?: string;
  /** Worth queuing another attempt. False for "she has no phone registered". */
  readonly retryable?: boolean;
  readonly devices: readonly PushDeviceOutcome[];
}

/** The one thing every push backend has to be able to do. */
export interface PushBackend {
  readonly name: string;
  isConfigured(): boolean;
  send(message: PushMessage): Promise<PushOutcome>;
}

/** Folds per-device results into the one answer the delivery row records. */
export function summarise(
  devices: readonly PushDeviceOutcome[],
): PushOutcome {
  const delivered = devices.filter((device) => device.ok);
  if (delivered.length > 0) {
    return {
      delivered: true,
      providerMessageId: delivered[0].providerMessageId,
      devices,
      // Partial success is still success for the customer — she got it on the
      // phone in her hand — but the failures are worth a line on the row.
      reason:
        delivered.length === devices.length
          ? undefined
          : `${devices.length - delivered.length} of ${devices.length} devices failed`,
    };
  }

  return {
    delivered: false,
    reason: devices[0]?.reason ?? 'Push provider refused every device',
    // Only worth another attempt if something transient refused it. Every
    // device reporting a dead token means there is nowhere left to send.
    retryable: devices.some((device) => device.retryable),
    devices,
  };
}
