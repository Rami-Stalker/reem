import {
  CanActivate,
  ExecutionContext,
  Injectable,
  SetMetadata,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { DeviceProofService } from '../../modules/auth/device/device-proof.service';

export const DEVICE_PROOF_KEY = 'device_proof';

/**
 * Marks a route as accepting a device proof.
 *
 * `required: true` refuses the request without one. `required: false` — the
 * default — verifies a proof when the caller supplies one and lets the handler
 * decide what to do with the result. That distinction is what makes a gradual
 * rollout possible: clients that have not shipped a key yet keep working, and
 * the routes that must have one say so explicitly.
 */
export const DeviceProof = (required = false) =>
  SetMetadata(DEVICE_PROOF_KEY, { required });

/** Attached to the request for handlers that care which device this was. */
export interface ProvenDevice {
  deviceKeyId: string;
}

@Injectable()
export class DeviceProofGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly proofs: DeviceProofService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const config = this.reflector.getAllAndOverride<{ required: boolean }>(
      DEVICE_PROOF_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!config) return true;

    const request = context
      .switchToHttp()
      .getRequest<Request & { provenDevice?: ProvenDevice }>();
    const header = request.get('x-reem-device-proof');

    if (!header) {
      if (config.required) {
        throw new UnauthorizedException({
          code: 'DEVICE_PROOF_REQUIRED',
          message: 'This action must be signed by a registered device',
        });
      }
      return true;
    }

    const bearer = request.get('authorization');
    const result = await this.proofs.verify(header, {
      method: request.method,
      url: `${request.protocol}://${request.get('host')}${request.originalUrl}`,
      accessToken: bearer?.startsWith('Bearer ')
        ? bearer.slice('Bearer '.length)
        : undefined,
    });

    if (!result.ok) {
      // The reason is deliberately in the body: the client has to be able to
      // tell "your clock is wrong" from "re-enrol this device", and neither is
      // information an attacker gains anything from.
      throw new UnauthorizedException({
        code: 'DEVICE_PROOF_INVALID',
        message: 'Device proof rejected',
        reason: result.reason,
      });
    }

    request.provenDevice = { deviceKeyId: result.deviceKey.id };
    return true;
  }
}
