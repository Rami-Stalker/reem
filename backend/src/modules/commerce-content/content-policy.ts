import { CommerceContentTypeDefinition, UserRole } from '@prisma/client';

/**
 * The rules about *what* a woman may publish, as pure functions.
 *
 * Separated from the service because each one is a product decision the client
 * made, and a decision buried in a 700-line service is a decision nobody can
 * find when it needs to change. Every function here is total, synchronous and
 * testable without a database.
 */

function capabilities(
  definition: CommerceContentTypeDefinition,
): Record<string, unknown> {
  const value = definition.capabilities;
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

export type ContentAudience = 'seller' | 'customer';

export function audienceFor(role: UserRole): ContentAudience {
  return role === UserRole.CUSTOMER ? 'customer' : 'seller';
}

/**
 * Whether this role may publish this format at all.
 *
 * Read from the registry row rather than from a list in code. Three things
 * follow: the composer can build itself from the same answer the server
 * enforces, enabling customer reels is a row edit rather than a deploy, and a
 * format added without an `audiences` key **fails closed to sellers only** —
 * which is the safe reading of an author who did not say.
 */
export function mayPublish(
  definition: CommerceContentTypeDefinition,
  role: UserRole,
): boolean {
  // Staff publish anything, including on somebody's behalf.
  if (
    role === UserRole.SUPER_ADMIN ||
    role === UserRole.OPERATIONS_ADMIN ||
    role === UserRole.CONTENT_MODERATOR ||
    role === UserRole.ADMIN
  ) {
    return true;
  }

  const declared = capabilities(definition).audiences;
  const audiences = Array.isArray(declared)
    ? declared.filter((value): value is string => typeof value === 'string')
    : ['seller'];

  return audiences.includes(audienceFor(role));
}

/** A reel without a video is not a reel. */
export function requiresVideo(definition: CommerceContentTypeDefinition): boolean {
  return capabilities(definition).video_required === true;
}

/** Q142 — thirty seconds, so the ops budget survives the uplink. */
export function maxDurationMs(
  definition: CommerceContentTypeDefinition,
): number | null {
  const seconds = capabilities(definition).max_duration_seconds;
  return typeof seconds === 'number' && seconds > 0 ? seconds * 1_000 : null;
}

export function maxMedia(definition: CommerceContentTypeDefinition): number | null {
  const value = capabilities(definition).max_media;
  return typeof value === 'number' && value > 0 ? value : null;
}

/**
 * Whether this piece has to be looked at before anybody else sees it.
 *
 * The owner's decision, and the compromise that lets customer content exist at
 * all on a platform whose imagery policy (Q105) was written for catalogue
 * photography. A woman's first few posts are reviewed; after that she publishes
 * straight to the feed and moderation is reactive — reports, word filtering,
 * takedowns.
 *
 * `approvedCount` is how many of her pieces have already been through it, so
 * the gate lifts itself rather than needing anybody to remember to lift it.
 */
export function needsPrePublishReview(input: {
  definition: CommerceContentTypeDefinition;
  role: UserRole;
  approvedCount: number;
  reviewFreeAfter: number;
}): boolean {
  if (capabilities(input.definition).moderation_required === true) return true;

  // A boutique is a verified business with a bank account and an ID on file.
  // The trust question has already been asked of her, at onboarding.
  if (input.role !== UserRole.CUSTOMER) return false;

  return input.approvedCount < input.reviewFreeAfter;
}

/**
 * Words that get a piece flagged for a human rather than refused.
 *
 * Q103 asks for automatic banned-word filtering. Flagging rather than refusing
 * is deliberate: a list of forbidden strings applied to Arabic will catch
 * innocent text — a word that is an insult in one dialect is a fabric in
 * another — and a woman told "your caption is not allowed" with no way to
 * appeal simply leaves. A flag costs a moderator ten seconds.
 *
 * The list is intentionally short and lives beside the rule it serves. It is a
 * `SystemSetting` candidate the moment somebody wants to tune it without a
 * deploy.
 */
const FLAGGED_TERMS = [
  'واتساب',
  'whatsapp',
  'تليجرام',
  'telegram',
  'رقمي',
  'خارج التطبيق',
];

/**
 * Off-platform contact details are what this actually catches: a seller moving
 * a sale into a private chat takes the buyer outside every protection the
 * platform offers her — no escrow, no returns window, no dispute.
 */
export function screenText(...parts: (string | null | undefined)[]): string[] {
  const haystack = parts.filter(Boolean).join(' ').toLowerCase();
  return FLAGGED_TERMS.filter((term) => haystack.includes(term));
}
