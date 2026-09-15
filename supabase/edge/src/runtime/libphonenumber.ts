/**
 * `libphonenumber-js/max`, as class-validator imports it on the edge.
 *
 * class-validator loads it for `@IsPhoneNumber`, which the backend never uses:
 * phone numbers are validated by `common/phone/phone.ts`. The 300 KB of
 * metadata is dead weight on a function with a 5 MB deploy limit, so a call
 * that did reach it fails validation rather than passing silently.
 */
export function parsePhoneNumber(): never {
  throw new Error('libphonenumber-js is not bundled on the edge; use common/phone/phone.ts');
}
