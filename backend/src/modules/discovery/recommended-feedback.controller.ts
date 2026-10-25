import {
  Controller,
  Delete,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { DiscoveryService } from './discovery.service';

/**
 * «إزالة من المختارة لكِ» — her say over her own «For You» shelf.
 *
 * A controller of its own because `DiscoveryController` is public reading
 * (`@OptionalAuth`); these are writes and need a session.
 */
@SelfScoped(
  "writes only the caller's own dismissal, keyed by the id in her token",
)
@Controller('discovery/recommended')
export class RecommendedFeedbackController {
  constructor(private readonly discovery: DiscoveryService) {}

  @Post(':productId/dismiss')
  @HttpCode(HttpStatus.OK)
  dismiss(
    @CurrentUser('id') userId: string,
    @Param('productId', ParseUUIDPipe) productId: string,
  ) {
    return this.discovery.dismissRecommendation(userId, productId);
  }

  @Delete(':productId/dismiss')
  restore(
    @CurrentUser('id') userId: string,
    @Param('productId', ParseUUIDPipe) productId: string,
  ) {
    return this.discovery.restoreRecommendation(userId, productId);
  }
}
