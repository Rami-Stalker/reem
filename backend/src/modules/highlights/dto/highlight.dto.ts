import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/**
 * Ceilings, stated once.
 *
 * A highlight rail is read whole — the profile draws every one of them — so
 * these are the line past which one account stops being able to cost the
 * platform a page. Set where a real person never reaches them: thirty shelves
 * of a hundred stories each is four times what the busiest boutique in the
 * beta has published in total.
 */
export const MAX_HIGHLIGHTS_PER_OWNER = 30;
export const MAX_ITEMS_PER_HIGHLIGHT = 100;

export class CreateHighlightDto {
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  cover_url?: string;

  /// The stories it opens with. Optional: a shelf may be named before it is
  /// filled, which is how «إطلالاتي» gets made before the first look exists.
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(MAX_ITEMS_PER_HIGHLIGHT)
  @IsUUID('4', { each: true })
  content_ids?: string[];
}

export class UpdateHighlightDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  cover_url?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  sort_order?: number;
}

export class AddHighlightItemDto {
  @IsUUID()
  content_id!: string;
}

/// Her whole rail, reordered in one request — dragging one shelf past another
/// moves both, and two PATCHes would leave a visible half-applied order.
export class ReorderHighlightsDto {
  @IsArray()
  @ArrayMaxSize(MAX_HIGHLIGHTS_PER_OWNER)
  @IsUUID('4', { each: true })
  highlight_ids!: string[];
}
