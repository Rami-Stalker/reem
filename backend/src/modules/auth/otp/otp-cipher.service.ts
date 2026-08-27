import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from 'crypto';

/**
 * Reversible sealing for the one-time code, used only by the outbox.
 *
 * The verification path stores a one-way HMAC and that does not change. But
 * escalation has to resend the *same* code on the next transport — a woman
 * already looking at a code must never be told to request a new one because
 * WhatsApp was quiet — and a digest cannot be un-hashed. So the outbox keeps
 * the code sealed, under its own key, and destroys it the moment the challenge
 * is delivered, consumed or expires.
 *
 * AES-256-GCM: authenticated, so a tampered ciphertext fails to open rather
 * than yielding a wrong code, and the random IV means two identical codes do
 * not produce identical rows.
 */
@Injectable()
export class OtpCipherService {
  private readonly key: Buffer;

  constructor(config: ConfigService) {
    const secret = config.get<string>('security.otpDeliveryKey') as string;
    // The key material is a passphrase in the environment; SHA-256 turns it
    // into the exactly-32-byte key AES-256 requires.
    this.key = createHash('sha256').update(secret).digest();
  }

  /** `iv.ciphertext.tag`, all base64url. */
  seal(plaintext: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    const sealed = Buffer.concat([
      cipher.update(plaintext, 'utf8'),
      cipher.final(),
    ]);
    return [
      iv.toString('base64url'),
      sealed.toString('base64url'),
      cipher.getAuthTag().toString('base64url'),
    ].join('.');
  }

  /** Returns null for anything that does not open cleanly. */
  open(sealed: string | null): string | null {
    if (!sealed) return null;
    const parts = sealed.split('.');
    if (parts.length !== 3) return null;

    try {
      const decipher = createDecipheriv(
        'aes-256-gcm',
        this.key,
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
}
