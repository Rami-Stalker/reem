/**
 * Fixed sign-in codes for a handful of named test accounts — a stopgap while
 * no SMS or WhatsApp provider is contracted, so a hosted test environment can
 * be signed into at all.
 *
 * Configured entirely by environment, never in the repository:
 *
 *   OTP_TEST_ACCOUNTS="+963911111111:123456,+963922222222:654321"
 *   OTP_TEST_ACCOUNTS_UNTIL=2026-10-01T00:00:00Z
 *
 * What it does, and all it does: when a LOGIN code is requested for one of
 * these numbers **and an account with that number already exists**, the
 * challenge is created with the configured code instead of a random one, and
 * nothing is queued for delivery. Verification is the unchanged path — the
 * code is hashed, attempts are counted, the challenge expires, the per-number
 * rate limits apply. A number that is not listed, or not registered, gets the
 * ordinary random code through the ordinary transports.
 *
 * Bounded on purpose:
 *  - `OTP_TEST_ACCOUNTS_UNTIL` is required and at most 30 days out; past it the
 *    codes stop working without a restart, and a production boot again
 *    requires a real provider;
 *  - at most five accounts, six-digit codes, E.164 numbers;
 *  - the codes are never logged.
 *
 * Remove both variables once a provider is live.
 */

export const MAX_TEST_ACCOUNT_DAYS = 30;
const MAX_TEST_ACCOUNTS = 5;

export interface OtpTestAccounts {
  codes: Map<string, string>;
  until: Date | null;
}

/** Parses the two variables; throws with a readable reason when malformed. */
export function parseOtpTestAccounts(
  raw: string | undefined,
  untilRaw: string | undefined,
): OtpTestAccounts {
  const codes = new Map<string, string>();
  const value = (raw ?? '').trim();
  if (!value) return { codes, until: null };

  for (const entry of value.split(',').map((e) => e.trim()).filter(Boolean)) {
    const match = entry.match(/^(\+\d{8,15}):(\d{6})$/);
    if (!match) {
      throw new Error(
        'OTP_TEST_ACCOUNTS entries must look like +963911111111:123456 (E.164 number, six-digit code)',
      );
    }
    if (codes.has(match[1])) {
      throw new Error(`OTP_TEST_ACCOUNTS lists ${maskPhone(match[1])} twice`);
    }
    codes.set(match[1], match[2]);
  }
  if (codes.size > MAX_TEST_ACCOUNTS) {
    throw new Error(`OTP_TEST_ACCOUNTS allows at most ${MAX_TEST_ACCOUNTS} accounts`);
  }

  const until = new Date((untilRaw ?? '').trim());
  if (!untilRaw?.trim() || Number.isNaN(until.getTime())) {
    throw new Error(
      'OTP_TEST_ACCOUNTS requires OTP_TEST_ACCOUNTS_UNTIL, an ISO instant such as 2026-10-01T00:00:00Z',
    );
  }
  return { codes, until };
}

/** Whether the fixed codes are in force at `now`. */
export function testAccountsActive(accounts: OtpTestAccounts, now = Date.now()): boolean {
  return accounts.codes.size > 0 && accounts.until !== null && accounts.until.getTime() > now;
}

function maskPhone(phone: string): string {
  return phone.length <= 8 ? phone : `${phone.slice(0, 5)}****${phone.slice(-4)}`;
}
