import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/**
 * A word is capped well above any real one.
 *
 * The cap is not a guess about Arabic — it is a bound on what gets folded and
 * stored on a path that runs inside every search's expansion table.
 */
const MAX_TERM = 60;

export class CreateSynonymGroupDto {
  @IsArray()
  @ArrayMinSize(2, { message: 'A synonym group needs at least two words' })
  @ArrayMaxSize(24)
  @IsString({ each: true })
  @MinLength(1, { each: true })
  @MaxLength(MAX_TERM, { each: true })
  terms!: string[];

  @IsOptional()
  @IsString()
  @MaxLength(120)
  note?: string;
}

export class AddSynonymTermDto {
  @IsString()
  @MinLength(1)
  @MaxLength(MAX_TERM)
  term!: string;
}

export class SetSynonymActiveDto {
  @IsBoolean()
  is_active!: boolean;
}

export class UnansweredQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit? = 25;
}
