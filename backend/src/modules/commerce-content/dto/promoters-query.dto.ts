import { IsOptional, IsUUID } from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';

/**
 * Whose promoters, and which page of them.
 *
 * One DTO, because validation refuses undeclared properties: a route that
 * binds `@Query()` to `PaginationDto` and reads `seller_id` beside it with
 * `@Query('seller_id')` answers 400 the moment anybody actually passes the
 * parameter — an admin looking at one boutique's list, in this case.
 */
export class PromotersQueryDto extends PaginationDto {
  @IsOptional()
  @IsUUID()
  seller_id?: string;
}
