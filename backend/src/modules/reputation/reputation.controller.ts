import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { ReputationService } from './reputation.service';
import {
  AwardSellerBadgeDto,
  CreateReviewDto,
  ModerateReviewDto,
  ReplyToReviewDto,
  RequestTrustedSellerVerificationDto,
  ReviewTrustedSellerVerificationDto,
  SellerReviewQueryDto,
} from './dto/reputation.dto';

@Controller('reputation')
export class ReputationController {
  constructor(private readonly reputation: ReputationService) {}

  @OptionalAuth()
  @Get('products/:productId/reviews')
  productReviews(
    @Param('productId', ParseUUIDPipe) productId: string,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.reputation.productReviews(productId, viewerId);
  }

  @Post('products/:productId/reviews')
  @HttpCode(HttpStatus.CREATED)
  createProductReview(
    @CurrentUser('id') userId: string,
    @Param('productId', ParseUUIDPipe) productId: string,
    @Body() dto: CreateReviewDto,
  ) {
    return this.reputation.createProductReview(userId, productId, dto);
  }

  /**
   * Her own reviews. Declared above `sellers/:sellerId` so the literal `me`
   * segment is never parsed as a UUID.
   */
  @Get('me/reviews')
  myReviews(@CurrentUser('id') userId: string) {
    return this.reputation.reviewsByAuthor(userId);
  }

  @Get('sellers/:sellerId/reviews')
  sellerReviews(@Param('sellerId', ParseUUIDPipe) sellerId: string) {
    return this.reputation.sellerReviews(sellerId);
  }

  @Post('sellers/:sellerId/reviews')
  @HttpCode(HttpStatus.CREATED)
  createSellerReview(
    @CurrentUser('id') userId: string,
    @Param('sellerId', ParseUUIDPipe) sellerId: string,
    @Body() dto: CreateReviewDto,
  ) {
    return this.reputation.createSellerReview(userId, sellerId, dto);
  }

  @Get('sellers/:sellerId')
  sellerReputation(@Param('sellerId', ParseUUIDPipe) sellerId: string) {
    return this.reputation.sellerReputation(sellerId);
  }

  @Post('seller/trusted-verification')
  @Roles(UserRole.SELLER)
  @HttpCode(HttpStatus.CREATED)
  requestTrustedVerification(
    @CurrentUser('id') sellerId: string,
    @Body() dto: RequestTrustedSellerVerificationDto,
  ) {
    return this.reputation.requestTrustedVerification(sellerId, dto);
  }

  // ── The seller ───────────────────────────────────────────────────────

  /**
   * Every review of her goods and her shop, merged and sorted together, with
   * a count of the ones still unanswered.
   */
  @Get('seller/reviews')
  @Roles(UserRole.SELLER)
  sellerReviewDesk(
    @CurrentUser('id') sellerId: string,
    @Query() query: SellerReviewQueryDto,
  ) {
    return this.reputation.reviewsForSeller(sellerId, query.filter ?? 'all');
  }

  /**
   * She answers one, publicly. An empty body removes her reply.
   *
   * The route is hers rather than the moderator's on purpose: a reply is not
   * moderation. She cannot change the rating, the words, or whether the review
   * is published — only add her side underneath it.
   */
  @Post('seller/reviews/:id/reply')
  @HttpCode(HttpStatus.OK)
  @Roles(UserRole.SELLER)
  replyToReview(
    @CurrentUser('id') sellerId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReplyToReviewDto,
  ) {
    return this.reputation.replyToReview(
      sellerId,
      id,
      dto.target_type,
      dto.reply,
    );
  }

  @Get('admin/moderation-queue')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  moderationQueue() {
    return this.reputation.moderationQueue();
  }

  @Patch('admin/reviews')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  moderateReview(
    @CurrentUser('id') moderatorId: string,
    @Body() dto: ModerateReviewDto,
  ) {
    return this.reputation.moderateReview(moderatorId, dto);
  }

  @Post('admin/badges')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  @HttpCode(HttpStatus.CREATED)
  awardBadge(@Body() dto: AwardSellerBadgeDto) {
    return this.reputation.awardBadge(dto);
  }

  @Patch('admin/sellers/:sellerId/trusted-verification')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  reviewTrustedVerification(
    @CurrentUser('id') moderatorId: string,
    @Param('sellerId', ParseUUIDPipe) sellerId: string,
    @Body() dto: ReviewTrustedSellerVerificationDto,
  ) {
    return this.reputation.reviewTrustedVerification(moderatorId, sellerId, dto);
  }
}
