import { SetMetadata } from '@nestjs/common';
import { AssuranceLevel } from '@prisma/client';

export const STEP_UP_KEY = 'step_up';

export interface StepUpRequirement {
  level: AssuranceLevel;
  /**
   * The action class this route belongs to. A grant is scoped, so a code the
   * user approved for a delivery-address change cannot silently also authorise
   * a payout change.
   *
   * Every scope used here must also appear in `STEP_UP_SCOPES`
   * (`auth/dto/step-up.dto.ts`), or the route becomes unreachable: the guard
   * demands an elevation the client has no valid way to request.
   */
  scope: string;
}

/**
 * Declares the assurance a route needs.
 *
 * `AAL2` — a fresh device proof on this request: it demonstrably came from the
 * enrolled handset, not from a stolen bearer token.
 *
 * `AAL3` — a second factor consumed in the last ten minutes, *and* a device
 * proof. Reserved for actions where being wrong is expensive or unsafe:
 * money, the phone number itself, and the controls an intruder would reach for
 * to lock the owner out.
 */
export const RequireStepUp = (level: AssuranceLevel, scope: string) =>
  SetMetadata(STEP_UP_KEY, { level, scope } satisfies StepUpRequirement);
