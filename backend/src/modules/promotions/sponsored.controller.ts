import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { PromotionPlacement } from '@prisma/client';
import { Transform } from 'class-transformer';
import { IsEnum, IsUUID } from 'class-validator';
import { Public } from '../../common/decorators/public.decorator';
import { PromotionsService } from './promotions.service';

class SponsoredClickDto {
  @IsUUID()
  offer_id!: string;

  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(PromotionPlacement)
  placement!: PromotionPlacement;
}

/**
 * The tap on a sponsored card.
 *
 * Public, because most of the people who see a paid slot are browsing signed
 * out. Safe to be public for the reason the service gives: the counter is
 * reporting only, and nothing about the money reads it. Throttled so one
 * phone cannot paint a competitor's click-through rate.
 */
@Controller('sponsored')
export class SponsoredController {
  constructor(private readonly promotions: PromotionsService) {}

  @Public()
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Post('clicks')
  @HttpCode(HttpStatus.NO_CONTENT)
  async click(@Body() dto: SponsoredClickDto): Promise<void> {
    await this.promotions.recordClick(dto.offer_id, dto.placement);
  }
}
