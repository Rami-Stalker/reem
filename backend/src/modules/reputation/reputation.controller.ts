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
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { ReputationService } from './reputation.service';
import {
  AwardSellerBadgeDto,
  CreateReviewDto,
  ModerateReviewDto,
  RequestTrustedSellerVerificationDto,
  ReviewTrustedSellerVerificationDto,
} from './dto/reputation.dto';

@Controller('reputation')
export class ReputationController {
  constructor(private readonly reputation: ReputationService) {}

  @Get('products/:productId/reviews')
  productReviews(@Param('productId', ParseUUIDPipe) productId: string) {
    return this.reputation.productReviews(productId);
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
