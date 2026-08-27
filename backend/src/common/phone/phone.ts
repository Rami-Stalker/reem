import { applyDecorators } from '@nestjs/common';
import { Transform } from 'class-transformer';
import { Matches, MaxLength } from 'class-validator';

/**
 * Phone numbers are the platform's only identity, so there is exactly one
 * canonical form for them: E.164, `+` followed by digits, stored and compared
 * verbatim.
 *
 * Everything else a Syrian user might type is an input format, not an
 * identity: `0912 345 678`, `00963912345678`, `963-912-345-678`, and the same
 * numbers written in Arabic-Indic digits, which is what an Arabic keyboard
 * produces by default. Without folding, the same woman registers as one
 * account and then cannot log into it — the lookup is a `findUnique` on a
 * string column, so `+963912345678` and `٠٩١٢٣٤٥٦٧٨` are simply different
 * people.
 *
 * Normalisation therefore happens at the DTO boundary via {@link PhoneField},
 * so no service, repository or query ever sees anything but E.164.
 */

/** The platform's home country; bare local formats are resolved against it. */
const DEFAULT_COUNTRY_CODE = '963';

/** Syrian mobile numbers are `09XXXXXXXX` — nine significant digits from `9`. */
const SYRIAN_MOBILE = /^9\d{8}$/;

/** E.164 allows at most 15 digits; 8 is the shortest plausible real number. */
const E164 = /^\+[1-9]\d{7,14}$/;

const ARABIC_INDIC_ZERO = 0x0660;
const EXTENDED_ARABIC_INDIC_ZERO = 0x06f0;

/** Folds Arabic-Indic (٠-٩) and Extended Arabic-Indic (۰-۹) digits to ASCII. */
export function foldDigits(value: string): string {
  let folded = '';
  for (const character of value) {
    const code = character.codePointAt(0) ?? 0;
    if (code >= ARABIC_INDIC_ZERO && code <= ARABIC_INDIC_ZERO + 9) {
      folded += String(code - ARABIC_INDIC_ZERO);
    } else if (
      code >= EXTENDED_ARABIC_INDIC_ZERO &&
      code <= EXTENDED_ARABIC_INDIC_ZERO + 9
    ) {
      folded += String(code - EXTENDED_ARABIC_INDIC_ZERO);
    } else {
      folded += character;
    }
  }
  return folded;
}

/**
 * Canonicalises anything a user might type into E.164, or returns `null` when
 * the input cannot be a phone number.
 *
 * Numbers outside Syria are accepted when already written in international
 * form — the platform serves Syria, but its own staff and the seeded demo
 * accounts are not all on Syrian numbers, and rejecting a valid E.164 number
 * would lock them out for no security gain.
 */
export function normalizePhone(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;

  // Strip every separator a human or a paste might introduce, including the
  // RTL marks an Arabic keyboard inserts around Latin digits.
  const cleaned = foldDigits(raw)
    .replace(/[\s\-().‎‏‪-‮⁦-⁩]/g, '')
    .trim();
  if (cleaned.length === 0) return null;

  let candidate: string;
  if (cleaned.startsWith('+')) {
    candidate = cleaned;
  } else if (cleaned.startsWith('00')) {
    candidate = `+${cleaned.slice(2)}`;
  } else if (cleaned.startsWith('0')) {
    // Local Syrian form: 09XXXXXXXX -> +9639XXXXXXXX
    candidate = `+${DEFAULT_COUNTRY_CODE}${cleaned.slice(1)}`;
  } else if (SYRIAN_MOBILE.test(cleaned)) {
    // Bare national significant number, as printed on shop signs.
    candidate = `+${DEFAULT_COUNTRY_CODE}${cleaned}`;
  } else if (cleaned.startsWith(DEFAULT_COUNTRY_CODE)) {
    candidate = `+${cleaned}`;
  } else {
    // An unprefixed foreign number is ambiguous and must not be guessed at.
    return null;
  }

  if (!/^\+\d+$/.test(candidate)) return null;
  if (!E164.test(candidate)) return null;

  // Inside Syria we know the plan, so an impossible number is rejected here
  // rather than becoming an account nobody can receive a code on.
  if (candidate.startsWith(`+${DEFAULT_COUNTRY_CODE}`)) {
    const national = candidate.slice(DEFAULT_COUNTRY_CODE.length + 1);
    if (!SYRIAN_MOBILE.test(national)) return null;
  }

  return candidate;
}

/** True when the value is already canonical E.164. */
export function isE164(value: unknown): boolean {
  return typeof value === 'string' && E164.test(value);
}

/**
 * Declares a request field as a phone number: folds and canonicalises it
 * before validation, then rejects anything that did not reach E.164.
 *
 * Invalid input is passed through unchanged rather than nulled, so the
 * validator — not the transformer — owns the error message.
 */
export function PhoneField(): PropertyDecorator {
  return applyDecorators(
    Transform(({ value }) => normalizePhone(value) ?? value),
    MaxLength(20),
    Matches(E164, {
      message:
        'phone must be a valid mobile number, e.g. 0912345678 or +963912345678',
    }),
  );
}
