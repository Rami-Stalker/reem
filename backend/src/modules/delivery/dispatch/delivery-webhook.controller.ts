import {
  Controller,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Request } from 'express';

import { Public } from '../../../common/decorators/public.decorator';
import { DeliveryWebhookService } from './delivery-webhook.service';

/**
 * Where delivery companies tell Reem what happened.
 *
 * Public, because a carrier has no session — so the signature is the only
 * thing between the internet and the ability to mark parcels delivered. It is
 * checked by the carrier's own adapter against the **raw** bytes (`rawBody`,
 * enabled in `main.ts`), because a signature verified against re-serialised
 * JSON fails on whitespace and key order.
 *
 * The path carries the carrier's code rather than a query parameter or a
 * header, so a carrier's callback URL is a constant they configure once and a
 * misdirected callback cannot be applied to another carrier's parcels.
 *
 * Throttled generously: a busy carrier sends a burst per parcel, and refusing
 * a legitimate flood would cost the platform its delivery updates. The
 * signature check is what stops abuse, not the rate limit.
 */
@Public()
@Controller('webhooks/delivery')
export class DeliveryWebhookController {
  constructor(private readonly webhooks: DeliveryWebhookService) {}

  @Throttle({ default: { limit: 600, ttl: 60_000 } })
  @Post(':provider')
  @HttpCode(HttpStatus.OK)
  async receive(
    @Param('provider') provider: string,
    @Req() req: Request & { rawBody?: Buffer },
  ) {
    return this.webhooks.receive(provider, {
      rawBody: req.rawBody,
      headers: req.headers as Record<string, string | string[] | undefined>,
      body: req.body,
    });
  }
}
