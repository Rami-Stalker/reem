import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { AiAssistantService } from './ai-assistant.service';
import {
  AiRecommendationQueryDto,
  AiSuggestionQueryDto,
  GenerateProductDescriptionDto,
  GenerateTagsDto,
} from './dto/ai-assistant.dto';

/**
 * Recommendations, which are public, and one reading of her own behaviour,
 * which is not.
 */
@SelfScoped(
  "the behaviour analysis is computed from the caller's own browsing and order history and never takes a user id from the request",
)
@Controller('ai')
export class AiAssistantController {
  constructor(private readonly ai: AiAssistantService) {}

  @OptionalAuth()
  @Get('recommendations/products')
  productRecommendations(
    @CurrentUser('id') userId: string | undefined,
    @Query() dto: AiRecommendationQueryDto,
  ) {
    return this.ai.productRecommendations(userId, dto);
  }

  @OptionalAuth()
  @Get('products/:productId/similar')
  similarProducts(
    @Param('productId', ParseUUIDPipe) productId: string,
    @CurrentUser('id') userId: string | undefined,
    @Query() dto: AiRecommendationQueryDto,
  ) {
    return this.ai.similarProducts(productId, userId, dto);
  }

  @OptionalAuth()
  @Get('recommendations/sellers')
  sellerRecommendations(
    @CurrentUser('id') userId: string | undefined,
    @Query() dto: AiRecommendationQueryDto,
  ) {
    return this.ai.sellerRecommendations(userId, dto);
  }

  @OptionalAuth()
  @Get('search/suggestions')
  smartSearchSuggestions(
    @CurrentUser('id') userId: string | undefined,
    @Query() dto: AiSuggestionQueryDto,
  ) {
    return this.ai.smartSearchSuggestions(userId, dto);
  }

  @OptionalAuth()
  @Get('home-feed')
  personalizedHomeFeed(@CurrentUser('id') userId?: string) {
    return this.ai.personalizedHomeFeed(userId);
  }

  @Get('behavior/me')
  behavior(@CurrentUser('id') userId: string) {
    return this.ai.behaviorAnalysis(userId);
  }

  @Post('generate/product-description')
  @Roles(UserRole.SELLER, UserRole.ADMIN, UserRole.SUPER_ADMIN)
  generateDescription(
    @CurrentUser('id') userId: string,
    @Body() dto: GenerateProductDescriptionDto,
  ) {
    return this.ai.generateProductDescription(userId, dto);
  }

  @Post('generate/tags')
  @Roles(UserRole.SELLER, UserRole.ADMIN, UserRole.SUPER_ADMIN)
  generateTags(@CurrentUser('id') userId: string, @Body() dto: GenerateTagsDto) {
    return this.ai.generateTags(userId, dto);
  }
}
