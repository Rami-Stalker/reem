import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

export class PaginationDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit = 20;

  get skip(): number {
    return (this.page - 1) * this.limit;
  }
}

export interface PaginatedMeta {
  page: number;
  limit: number;
  total: number;
  total_pages: number;
  has_next_page: boolean;
}

export function buildMeta(
  page: number,
  limit: number,
  total: number,
  returned: number,
): PaginatedMeta {
  return {
    page,
    limit,
    total,
    total_pages: Math.ceil(total / limit),
    has_next_page: (page - 1) * limit + returned < total,
  };
}
