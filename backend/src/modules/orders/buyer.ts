import { UnauthorizedException } from '@nestjs/common';

import { RequestPrincipal } from '../../common/decorators/current-principal.decorator';

/**
 * Who is buying.
 *
 * Q46 P1 lets a guest buy, and the database has always been built for it —
 * `Order.userId` is nullable, `Order.guestSessionId` exists and is indexed,
 * `CodRiskAssessment.userId` is nullable with a comment saying "null on a
 * guest checkout". What was missing was the till: `POST /orders/checkout` took
 * a required `userId`, nothing anywhere wrote `guestSessionId`, and checkout
 * could only read the signed-in cart table. A visitor could fill a basket she
 * was never allowed to pay for.
 *
 * The same two-armed shape as `CartOwner`, deliberately: the basket and the
 * order it becomes are owned by the same person, and a second vocabulary for
 * that would be one more place the two could disagree.
 */
export type Buyer =
  | { kind: 'user'; userId: string }
  | { kind: 'guest'; guestSessionId: string };

/** The signed-in id, or null for a guest. The shape most call sites want. */
export function userIdOf(buyer: Buyer): string | null {
  return buyer.kind === 'user' ? buyer.userId : null;
}

/** The guest session id, or null for a signed-in customer. */
export function guestSessionIdOf(buyer: Buyer): string | null {
  return buyer.kind === 'guest' ? buyer.guestSessionId : null;
}

/**
 * The buyer behind a request.
 *
 * Throws rather than returning null when neither is present: every route that
 * uses this is behind `@Authorize({ allowGuest: true })`, which has already
 * resolved a guest session or refused — so reaching here with nothing is a
 * wiring mistake, not a customer's problem.
 */
export function buyerOf(principal: RequestPrincipal | undefined): Buyer {
  if (principal?.kind === 'user') {
    return { kind: 'user', userId: principal.user.id };
  }
  if (principal?.kind === 'guest') {
    return { kind: 'guest', guestSessionId: principal.guest.id };
  }
  throw new UnauthorizedException('A user or guest session is required');
}

/**
 * The `where` that selects one buyer's orders, and nobody else's.
 *
 * A guest's claim on her order is her session token, which is the same
 * credential that let her build the basket. It is weaker than an account and
 * that is the deal Q46 P1 makes; what matters is that it is *scoped* — one
 * guest cannot read another's order any more than one customer can.
 */
export function ownedByBuyer(buyer: Buyer) {
  return buyer.kind === 'user'
    ? { userId: buyer.userId }
    : { guestSessionId: buyer.guestSessionId };
}
