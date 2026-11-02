import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from 'crypto';

/**
 * Reversible sealing for a value that has to be read back by a person — a
 * payout card number, which the accountant needs in full to pay it and the
 * seller's own screens never show.
 *
 * AES-256-GCM: a tampered value fails to open instead of opening wrong, and
 * the random IV means one card sealed twice gives two different strings.
 *
 * The key is `PAYOUT_ACCOUNT_KEY` when set. Without it the key is derived
 * from `OTP_DELIVERY_KEY` under its own label, so the two purposes never
 * share a key even when they share a secret.
 */
function key(): Buffer {
  const own = process.env.PAYOUT_ACCOUNT_KEY;
  const secret = own && own.length >= 32
    ? own
    : `payout-account:${process.env.OTP_DELIVERY_KEY ?? ''}`;
  return createHash('sha256').update(secret).digest();
}

/** `iv.ciphertext.tag`, all base64url. */
export function sealText(plaintext: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key(), iv);
  const sealed = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  return [
    iv.toString('base64url'),
    sealed.toString('base64url'),
    cipher.getAuthTag().toString('base64url'),
  ].join('.');
}

/** Null for anything that does not open cleanly. */
export function openText(sealed: string | null | undefined): string | null {
  if (!sealed) return null;
  const parts = sealed.split('.');
  if (parts.length !== 3) return null;
  try {
    const decipher = createDecipheriv(
      'aes-256-gcm',
      key(),
      Buffer.from(parts[0], 'base64url'),
    );
    decipher.setAuthTag(Buffer.from(parts[2], 'base64url'));
    return Buffer.concat([
      decipher.update(Buffer.from(parts[1], 'base64url')),
      decipher.final(),
    ]).toString('utf8');
  } catch {
    return null;
  }
}
