import { Type } from 'class-transformer';
import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { DuplicateVerdict } from '@prisma/client';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export class DuplicateQueueQueryDto extends PaginationDto {
  /**
   * Narrows the sweep to one category. Pairs are only ever compared within a
   * category anyway — the service will not cross them — so this is a filter
   * on the queue, not a change of behaviour.
   */
  @IsOptional()
  @IsUUID()
  category_id?: string;

  /**
   * How alike two titles must read. Left alone by every normal caller; it
   * exists so a merchandiser working through a noisy category can tighten the
   * queue for an afternoon without a deploy.
   */
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.3)
  @Max(1)
  threshold?: number;
}

export class RecordDuplicateVerdictDto {
  @IsUUID()
  product_id_a!: string;

  @IsUUID()
  product_id_b!: string;

  @IsEnum(DuplicateVerdict)
  verdict!: DuplicateVerdict;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class ClearDuplicateVerdictDto {
  @IsUUID()
  product_id_a!: string;

  @IsUUID()
  product_id_b!: string;
}
