import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { CONTENT_REPORT_REASONS } from '../../commerce-content/moderation/content-moderation.service';

/** `?ids=a,b,c` — the products a screen is showing right now. */
export class EngagementBatchQueryDto {
  @Transform(({ value }) =>
    (Array.isArray(value) ? value.join(',') : String(value ?? ''))
      .split(',')
      .map((id) => id.trim())
      .filter((id) => id.length > 0),
  )
  @IsArray()
  // A screen of cards, not a catalogue export. Sixty is two pages of a grid.
  @ArrayMaxSize(60)
  @IsUUID('all', { each: true })
  ids!: string[];
}

export class PickProductDto {
  @IsOptional()
  @IsString()
  @MaxLength(280)
  note?: string;
}

export class ReportProductDto {
  @IsIn(CONTENT_REPORT_REASONS)
  reason!: (typeof CONTENT_REPORT_REASONS)[number];

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  detail?: string;
}
