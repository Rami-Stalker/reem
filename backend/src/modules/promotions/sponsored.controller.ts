import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { PromotionPlacement } from '@prisma/client';
import { Transform } from 'class-transformer';
import { IsEnum, IsUUID } from 'class-validator';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
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
 * Open to guests, because most of the people who see a paid slot are browsing
 * signed out; a signed-in tap is also credited to her, which is what lets an
 * order she places afterwards be attributed to the advert. Safe to be public for the reason the service gives: the counter is
 * reporting only, and nothing about the money reads it. Throttled so one
 * phone cannot paint a competitor's click-through rate.
 */
@Controller('sponsored')
export class SponsoredController {
  constructor(private readonly promotions: PromotionsService) {}

  @OptionalAuth()
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Post('clicks')
  @HttpCode(HttpStatus.NO_CONTENT)
  async click(
    @Body() dto: SponsoredClickDto,
    @CurrentUser('id') viewerId?: string,
  ): Promise<void> {
    await this.promotions.recordClick(dto.offer_id, dto.placement, viewerId);
  }
}
