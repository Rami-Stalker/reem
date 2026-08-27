import { createPublicKey, timingSafeEqual, verify } from 'crypto';

/**
 * Ed25519 signature verification over raw public keys.
 *
 * Deliberately built on node's own `crypto.verify` rather than a hand-rolled
 * parser. The service this replaces did split JWTs by hand, and that is
 * precisely how it ended up trusting an unsigned token — so the rule here is
 * that nothing is parsed until the algorithm has been checked, and the
 * signature is verified over the exact bytes that were signed.
 */

/** DER prefix for an Ed25519 SubjectPublicKeyInfo — 12 bytes then the key. */
const SPKI_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');
const RAW_KEY_LENGTH = 32;
const SIGNATURE_LENGTH = 64;

/** Wraps a raw 32-byte Ed25519 public key so node can use it. */
export function publicKeyFromRaw(base64url: string) {
  const raw = Buffer.from(base64url, 'base64url');
  if (raw.length !== RAW_KEY_LENGTH) {
    throw new Error('Ed25519 public keys are 32 bytes');
  }
  return createPublicKey({
    key: Buffer.concat([SPKI_PREFIX, raw]),
    format: 'der',
    type: 'spki',
  });
}

/** True when `signature` is a valid Ed25519 signature of `message`. */
export function verifyEd25519(
  message: Buffer,
  signature: Buffer,
  publicKeyBase64Url: string,
): boolean {
  if (signature.length !== SIGNATURE_LENGTH) return false;
  try {
    return verify(null, message, publicKeyFromRaw(publicKeyBase64Url), signature);
  } catch {
    return false;
  }
}

export interface CompactJwsParts {
  header: Record<string, unknown>;
  payload: Record<string, unknown>;
  signingInput: Buffer;
  signature: Buffer;
}

/**
 * Splits a compact JWS and refuses anything that is not EdDSA **before**
 * touching the payload.
 *
 * The order matters. `alg: none` and algorithm-confusion attacks work by
 * getting a verifier to read the claims first and decide how to check them
 * afterwards; checking the algorithm first means an attacker-chosen `alg`
 * never reaches any code path that could act on it.
 */
export function parseCompactJws(token: string): CompactJwsParts | null {
  const parts = token.split('.');
  if (parts.length !== 3) return null;

  let header: Record<string, unknown>;
  try {
    header = JSON.parse(
      Buffer.from(parts[0], 'base64url').toString('utf8'),
    ) as Record<string, unknown>;
  } catch {
    return null;
  }

  if (header.alg !== 'EdDSA') return null;
  if (header.typ !== undefined && header.typ !== 'device-proof+jwt') return null;

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(
      Buffer.from(parts[1], 'base64url').toString('utf8'),
    ) as Record<string, unknown>;
  } catch {
    return null;
  }

  return {
    header,
    payload,
    signingInput: Buffer.from(`${parts[0]}.${parts[1]}`, 'utf8'),
    signature: Buffer.from(parts[2], 'base64url'),
  };
}

/** Constant-time comparison for the access-token binding digest. */
export function safeEqual(a: string, b: string): boolean {
  const left = Buffer.from(a, 'utf8');
  const right = Buffer.from(b, 'utf8');
  if (left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}
