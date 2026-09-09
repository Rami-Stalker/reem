import { IsOptional, IsString, MaxLength } from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';

/**
 * Her order list: which pile, and which page of it.
 *
 * Both in one DTO because validation refuses properties no DTO declares.
 * Binding `@Query()` to `PaginationDto` and reading `bucket` beside it with
 * `@Query('bucket')` left `bucket` undeclared, so every tab of the orders
 * screen except «الكل» answered 400 and rendered as an empty list.
 *
 * Deliberately a plain string rather than an enum: the controller ignores a
 * bucket it does not know and shows everything, which is what a stale link
 * from an old build should do — not fail.
 */
export class OrderQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  bucket?: string;
}
