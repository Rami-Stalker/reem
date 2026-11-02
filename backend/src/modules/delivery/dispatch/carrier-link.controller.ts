import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Res,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Response } from 'express';
import { randomBytes } from 'node:crypto';

import { Public } from '../../../common/decorators/public.decorator';
import { CarrierStepDto } from '../dto/carrier-link.dto';
import { CARRIER_STEPS, CarrierLinkService, CarrierStep } from './carrier-link.service';
import { carrierLinkPage } from './carrier-link.page';

/**
 * The driver link. Public on purpose: the secret in the URL is the
 * credential, and it opens one parcel only. Throttled tightly, so the link
 * cannot be used to guess the customer's code.
 */
@Public()
@Controller('carrier')
export class CarrierLinkController {
  constructor(private readonly links: CarrierLinkService) {}

  /** The page the driver opens on his phone. */
  @Get(':token')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  page(@Param('token') token: string, @Res() res: Response) {
    const nonce = randomBytes(16).toString('base64');
    res.setHeader(
      'Content-Security-Policy',
      [
        "default-src 'none'",
        `script-src 'nonce-${nonce}'`,
        "style-src 'unsafe-inline'",
        "connect-src 'self'",
        "img-src 'self' data:",
        "base-uri 'none'",
        "form-action 'none'",
        "frame-ancestors 'none'",
      ].join('; '),
    );
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.type('html').send(carrierLinkPage(nonce));
  }

  @Get(':token/parcel')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  view(@Param('token') token: string) {
    return this.links.view(token);
  }

  @Post(':token/:step')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  act(
    @Param('token') token: string,
    @Param('step') step: string,
    @Body() dto: CarrierStepDto,
  ) {
    const known = CARRIER_STEPS.find((candidate) => candidate === step.replace(/-/g, '_'));
    return this.links.actByToken(token, (known ?? step) as CarrierStep, {
      handoverCode: dto.handover_code,
      collected: dto.collected,
      reason: dto.reason,
      note: dto.note,
    });
  }
}
