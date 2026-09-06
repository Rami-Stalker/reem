import { Controller, Get, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { CategoriesService } from './categories.service';

/**
 * Reading the catalog's category tree.
 *
 * Public on purpose: the same tree drives the buyer's browse rails and the
 * seller's product form, and gating it behind a session would mean a guest
 * cannot see what the shop sells.
 */
@Controller('categories')
export class CategoriesController {
  constructor(private readonly categories: CategoriesService) {}

  /** The whole tree, nested. `?leaves=true` flattens it to the selectable end. */
  @Public()
  @Get()
  list(@Query('leaves') leaves?: string) {
    return leaves === 'true' || leaves === '1'
      ? this.categories.leaves()
      : this.categories.tree();
  }

  /** One category with its resolved attribute schema and size chart. */
  @Public()
  @Get(':id')
  detail(@Param('id', ParseUUIDPipe) id: string) {
    return this.categories.detail(id);
  }
}
