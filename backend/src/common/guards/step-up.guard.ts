import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AssuranceLevel } from '@prisma/client';
import { Request } from 'express';
import { AuthUser } from '../decorators/current-user.decorator';
import {
  STEP_UP_KEY,
  StepUpRequirement,
} from '../decorators/require-step-up.decorator';
import { StepUpService } from '../../modules/auth/step-up/step-up.service';
import { ProvenDevice } from './device-proof.guard';

/**
 * Enforces the assurance ladder.
 *
 * Two refusals, and the difference between them is the whole point:
 *
 * `STEP_UP_REQUIRED` means "prove it again and you may proceed" — the client
 * shows a code prompt and retries.
 *
 * `NEW_DEVICE_COOLDOWN` means "not from this device yet, at any assurance".
 * There is no prompt that clears it, because the only factor a consumer can
 * present today arrives on the SIM, and SIM possession is exactly the attack
 * being defended against. A day of delay is the only control that does not
 * route back through the attacker's hand.
 */
@Injectable()
export class StepUpGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly stepUp: StepUpService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requirement = this.reflector.getAllAndOverride<StepUpRequirement>(
      STEP_UP_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requirement) return true;

    const request = context.switchToHttp().getRequest<
      Request & { user?: AuthUser; provenDevice?: ProvenDevice }
    >();
    const user = request.user;
    if (!user) return true; // JwtAuthGuard already refused, or the route is public.

    // AAL2 and above both need the request to come from the enrolled handset.
    if (!request.provenDevice) {
      throw new ForbiddenException({
        code: 'DEVICE_PROOF_REQUIRED',
        message: 'تعذّر التحقق من جهازكِ لهذا الإجراء. حدّثي التطبيق أو سجّلي الدخول من جديد',
        scope: requirement.scope,
      });
    }

    if (requirement.level === AssuranceLevel.AAL2) return true;

    const state = user.sessionId
      ? await this.stepUp.stateOf(user.sessionId)
      : null;

    if (state?.cooldownUntil) {
      throw new ForbiddenException({
        code: 'NEW_DEVICE_COOLDOWN',
        message:
          'هذا الجهاز جديد. هذا الإجراء متاح بعد مرور 24 ساعة على أول تسجيل دخول منه.',
        scope: requirement.scope,
        available_at: state.cooldownUntil.toISOString(),
      });
    }

    if (state?.level !== AssuranceLevel.AAL3) {
      throw new ForbiddenException({
        code: 'STEP_UP_REQUIRED',
        message: 'أكّدي هويتكِ للمتابعة',
        scope: requirement.scope,
      });
    }

    return true;
  }
}
