import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { HighlightsService } from './highlights.service';
import {
  AddHighlightItemDto,
  CreateHighlightDto,
  ReorderHighlightsDto,
  UpdateHighlightDto,
} from './dto/highlight.dto';

class ArchiveQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;
}

/**
 * «الأبرز» — the stories kept on a page past their day.
 *
 * Reading a rail is public, because a page is: a shared storefront link has to
 * open for a woman who has not signed in, and her own highlights are the first
 * thing on it. Writing is not — every write is scoped to the caller's own id
 * inside the service, which is a rule about the row rather than one the
 * `Authorize` guard can state, hence `@SelfScoped`.
 */
@SelfScoped(
  "every highlight is created, edited and deleted against the caller's own id inside the service",
)
@Controller('highlights')
export class HighlightsController {
  constructor(private readonly highlights: HighlightsService) {}

  /**
   * Her own rail, empty shelves included.
   *
   * Declared before `:userId` so the literal is not swallowed by the
   * parameter — the same ordering rule the rooms and seller routes follow.
   */
  @Get('me')
  mine(@CurrentUser('id') userId: string) {
    return this.highlights.listFor(userId, userId);
  }

  /** Her own stories, live and expired, to pick from. */
  @Get('me/archive')
  archive(@CurrentUser('id') userId: string, @Query() query: ArchiveQueryDto) {
    return this.highlights.archive(userId, query.limit ?? 60);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser('id') userId: string, @Body() dto: CreateHighlightDto) {
    return this.highlights.create(userId, dto);
  }

  @Patch('order')
  reorder(
    @CurrentUser('id') userId: string,
    @Body() dto: ReorderHighlightsDto,
  ) {
    return this.highlights.reorder(userId, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateHighlightDto,
  ) {
    return this.highlights.update(userId, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  remove(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.highlights.remove(userId, id);
  }

  @Post(':id/items')
  @HttpCode(HttpStatus.CREATED)
  addItem(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AddHighlightItemDto,
  ) {
    return this.highlights.addItem(userId, id, dto);
  }

  @Delete(':id/items/:contentId')
  @HttpCode(HttpStatus.OK)
  removeItem(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('contentId', ParseUUIDPipe) contentId: string,
  ) {
    return this.highlights.removeItem(userId, id, contentId);
  }

  /**
   * One shelf, opened.
   *
   * Public with an optional session, so the viewer's own state travels when
   * there is one and a shared link still opens when there is not. Declared
   * after every literal path above.
   */
  @OptionalAuth()
  @Get('detail/:id')
  detail(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.highlights.detail(id, viewerId);
  }

  /** Anyone's rail, subject to whether her page is open. */
  @OptionalAuth()
  @Get(':userId')
  listFor(
    @Param('userId', ParseUUIDPipe) ownerId: string,
    @CurrentUser('id') viewerId?: string,
  ) {
    return this.highlights.listFor(ownerId, viewerId);
  }
}
