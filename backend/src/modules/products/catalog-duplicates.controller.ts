import {
  Body,
  Controller,
  Delete,
  Get,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import {
  ClearDuplicateVerdictDto,
  DuplicateQueueQueryDto,
  RecordDuplicateVerdictDto,
} from './dto/catalog-duplicates.dto';
import { CatalogDuplicatesService } from './catalog-duplicates.service';

/**
 * Two listings for one garment.
 *
 * The catalogue is built so that five boutiques selling the same dress share
 * one product page and compete on it. That only works while they are attached
 * to the same product row; a second row for a garment that already exists
 * splits the offers across two pages and quietly undoes the design. Nothing
 * looked for that until now.
 */
@Authorize({
  action: 'manage',
  resource: 'product',
  roles: [UserRole.SUPER_ADMIN, UserRole.OPERATIONS_ADMIN, UserRole.ADMIN],
  permissions: [AppPermission.productManage],
})
@Controller('admin/catalog/duplicates')
export class CatalogDuplicatesController {
  constructor(private readonly duplicates: CatalogDuplicatesService) {}

  @Get()
  async queue(@Query() query: DuplicateQueueQueryDto) {
    const candidates = await this.duplicates.candidates({
      categoryId: query.category_id,
      threshold: query.threshold,
      limit: query.limit,
      skip: query.skip,
    });
    return {
      data: candidates.map((candidate) => ({
        score: candidate.score,
        shares_seller: candidate.sharesSeller,
        left: this.side(candidate.left),
        right: this.side(candidate.right),
      })),
    };
  }

  @Get('decided')
  async decided(@Query() query: DuplicateQueueQueryDto) {
    const { rows, total } = await this.duplicates.decided({
      limit: query.limit,
      skip: query.skip,
    });
    return {
      data: rows.map((row) => ({
        id: row.id,
        verdict: row.verdict.toLowerCase(),
        note: row.note,
        decided_at: row.decidedAt.toISOString(),
        decided_by: row.decidedBy
          ? { id: row.decidedBy.id, name: row.decidedBy.name }
          : null,
        left: {
          id: row.leftProduct.id,
          title: row.leftProduct.title,
          slug: row.leftProduct.slug,
        },
        right: {
          id: row.rightProduct.id,
          title: row.rightProduct.title,
          slug: row.rightProduct.slug,
        },
      })),
      total,
    };
  }

  @Post('verdict')
  record(
    @CurrentUser() user: AuthUser,
    @Body() dto: RecordDuplicateVerdictDto,
  ) {
    return this.duplicates.record({
      productIdA: dto.product_id_a,
      productIdB: dto.product_id_b,
      verdict: dto.verdict,
      note: dto.note,
      decidedById: user.id,
    });
  }

  /** Puts a pair back in the queue — the ruling was wrong, or a title changed. */
  @Delete('verdict')
  clear(@Body() dto: ClearDuplicateVerdictDto) {
    return this.duplicates.clear(dto.product_id_a, dto.product_id_b);
  }

  private side(side: {
    id: string;
    title: string;
    slug: string;
    categoryId: string;
    offersCount: number;
    createdAt: Date;
  }) {
    return {
      id: side.id,
      title: side.title,
      slug: side.slug,
      category_id: side.categoryId,
      offers_count: side.offersCount,
      created_at: side.createdAt.toISOString(),
    };
  }
}
