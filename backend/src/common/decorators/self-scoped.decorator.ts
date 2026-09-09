import { SetMetadata } from '@nestjs/common';

export const SELF_SCOPED_KEY = 'self_scoped';

/**
 * "Every route here acts on the caller's own data, and the service enforces
 * it."
 *
 * **Why this exists.** `AuthorizationGuard` used to return `true` for any
 * route that declared no policy. That was not an accident — most of this
 * platform's customer routes are protected by an ownership check *inside* the
 * service (`where: { id, userId }`, `assertMayView`, `requireCourier`), which
 * is a perfectly good defence and often the only one that can express the
 * rule. The problem was that the guarantee could not be *read*: to know
 * whether a route was protected you had to open the service behind it, and a
 * new route added to one of these controllers inherited "allowed" silently.
 *
 * So the guard now fails closed, and this is how a controller says that its
 * protection lives one layer down. It is deliberately a **controller-level**
 * annotation carrying a **reason**: the reason is the point, because writing
 * it forces the author to name the check, and a reviewer can see in one line
 * what would otherwise take a file read.
 *
 * Use `@Authorize(...)`, `@Roles(...)` or `@RequirePermissions(...)` whenever
 * the rule *can* be stated declaratively. Reach for this only when the answer
 * genuinely depends on the row being touched.
 *
 * @param reason How the caller's own data is enforced. Shown in the boot-time
 *   authorization report.
 */
export const SelfScoped = (reason: string) =>
  SetMetadata(SELF_SCOPED_KEY, reason);
