import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { TrustSignalStatus, UserRole } from '@prisma/client';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import {
  ResolveTrustSignalDto,
  TrustQueueQueryDto,
  TrustSweepDto,
} from './dto/trust.dto';
import { TrustService } from './trust.service';

/**
 * The trust queue.
 *
 * Everything here is a reading with its evidence attached, and a place to
 * record what a person decided. There is no endpoint that hides a review or
 * freezes an account on a score alone — `resolve` is the only thing that
 * changes anything a customer can see, and a person has to call it.
 *
 * Sits behind `content:moderate`, the same permission that gates the content
 * queue: this is the same job, done on a different kind of object.
 */
@Authorize({
  action: 'moderate',
  resource: 'content',
  roles: [
    UserRole.SUPER_ADMIN,
    UserRole.OPERATIONS_ADMIN,
    UserRole.CONTENT_MODERATOR,
    UserRole.ADMIN,
  ],
  permissions: [AppPermission.contentModerate],
})
@Controller('admin/trust')
export class TrustAdminController {
  constructor(private readonly trust: TrustService) {}

  @Get('signals')
  queue(@Query() query: TrustQueueQueryDto) {
    return this.trust.queue({
      subject: query.subject,
      band: query.band,
      status: query.status,
      limit: query.limit,
      skip: query.skip,
    });
  }

  @Post('signals/:id/resolve')
  resolve(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ResolveTrustSignalDto,
  ) {
    if (dto.status === TrustSignalStatus.OPEN) {
      throw new BadRequestException(
        'Resolving a signal means confirming or dismissing it',
      );
    }
    return this.trust.resolve({
      signalId: id,
      status: dto.status,
      note: dto.note,
      actorId: user.id,
    });
  }

  /** Re-reads one review on demand — for a moderator who just changed something. */
  @Post('reviews/:id/rescore')
  rescoreReview(@Param('id', ParseUUIDPipe) id: string) {
    return this.trust.scoreOneReview(id);
  }

  @Post('sweep/reviews')
  sweepReviews(@Body() dto: TrustSweepDto) {
    return this.trust.sweepReviews(dto.since_days ?? 7, dto.limit ?? 500);
  }

  @Post('sweep/customers')
  sweepCustomers(@Body() dto: TrustSweepDto) {
    return this.trust.sweepCustomers(dto.since_days ?? 7, dto.limit ?? 500);
  }

  @Post('sweep/sellers')
  sweepSellers(@Body() dto: TrustSweepDto) {
    return this.trust.sweepSellers(dto.since_days ?? 7, dto.limit ?? 500);
  }

  /** Re-reads one boutique on demand. */
  @Post('sellers/:id/rescore')
  rescoreSeller(@Param('id', ParseUUIDPipe) id: string) {
    return this.trust.scoreSellerConduct(id);
  }
}
