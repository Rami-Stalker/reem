import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

/**
 * A one-request stand-in for a consumed sign-in code.
 *
 * When Supabase Auth has already confirmed the phone, the API still signs the
 * woman in through `AuthService.completeOtpLogin` — the backend's own path,
 * with its suspension checks, device binding, audit trail and guest-cart
 * migration — rather than a second, parallel implementation of all that.
 * That path begins by consuming an OTP. This proof is what it consumes.
 *
 * A proof is 256 random bits, bound to one phone number, valid for thirty
 * seconds and for a single use, and it never leaves the process: it is minted
 * and spent inside the same exchange request. It cannot be obtained, guessed
 * or replayed by a client, and the ordinary OTP path is untouched for every
 * code that is not one.
 */
const TTL_MS = 30_000;
const PREFIX = 'sbx.';

interface Pending {
  phone: string;
  digest: Buffer;
  expiresAt: number;
}

const pending = new Map<string, Pending>();

function digestOf(value: string): Buffer {
  return createHash('sha256').update(value).digest();
}

export function mintLoginProof(phone: string): string {
  const now = Date.now();
  for (const [id, entry] of pending) {
    if (entry.expiresAt <= now) pending.delete(id);
  }
  const id = randomBytes(9).toString('base64url');
  const secret = randomBytes(32).toString('base64url');
  const proof = `${PREFIX}${id}.${secret}`;
  pending.set(id, { phone, digest: digestOf(proof), expiresAt: now + TTL_MS });
  return proof;
}

/** True exactly once for a live proof minted for this phone. */
export function spendLoginProof(phone: string, candidate: string): boolean {
  if (!candidate.startsWith(PREFIX)) return false;
  const id = candidate.slice(PREFIX.length).split('.')[0] ?? '';
  const entry = pending.get(id);
  if (!entry) return false;
  pending.delete(id);
  if (entry.expiresAt <= Date.now() || entry.phone !== phone) return false;
  const candidateDigest = digestOf(candidate);
  return candidateDigest.length === entry.digest.length && timingSafeEqual(candidateDigest, entry.digest);
}

export function isLoginProof(candidate: string): boolean {
  return candidate.startsWith(PREFIX);
}
