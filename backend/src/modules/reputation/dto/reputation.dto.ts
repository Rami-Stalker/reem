import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsISO8601,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import {
  ReviewStatus,
  ReviewTargetType,
  SellerBadgeType,
  TrustVerificationStatus,
} from '@prisma/client';

export class CreateReviewDto {
  @IsOptional()
  @IsUUID()
  order_id?: string;

  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  body?: string;
}

/**
 * The seller answering a review of her goods or her shop.
 *
 * The target type has to be told: a product review and a seller review are
 * separate tables with separate ids, and guessing from the id would mean two
 * lookups on every reply.
 */
export class ReplyToReviewDto {
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(ReviewTargetType)
  target_type!: ReviewTargetType;

  /**
   * Empty removes the reply. A seller who answered in anger and thought
   * better of it should not have to ask a moderator to unpublish her own
   * sentence.
   */
  @IsString()
  @MaxLength(2000)
  reply!: string;
}

/** Which reviews the seller's desk is showing. */
export class SellerReviewQueryDto {
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toLowerCase() : value,
  )
  @IsIn(['all', 'unanswered'])
  filter?: 'all' | 'unanswered';
}

export class ModerateReviewDto {
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(ReviewTargetType)
  target_type!: ReviewTargetType;

  @IsUUID()
  review_id!: string;

  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(ReviewStatus)
  status!: ReviewStatus;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  reason?: string;
}

export class AwardSellerBadgeDto {
  @IsUUID()
  seller_id!: string;

  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(SellerBadgeType)
  type!: SellerBadgeType;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  label?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;

  @IsOptional()
  @IsISO8601()
  expires_at?: string;
}

export class RequestTrustedSellerVerificationDto {
  @IsOptional()
  evidence?: unknown;
}

export class ReviewTrustedSellerVerificationDto {
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(TrustVerificationStatus)
  status!: TrustVerificationStatus;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  reason?: string;
}
