import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import {
  CommerceAuthorKind,
  CommerceContentPublicationChannel,
  CommerceContentStatus,
} from '@prisma/client';
import { CursorPageDto } from '../../../common/dto/cursor-pagination.dto';
import { CONTENT_REPORT_REASONS } from '../moderation/content-moderation.service';

const upper = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.toUpperCase() : value;

export class ContentFeedQueryDto extends CursorPageDto {
  @IsOptional()
  @Transform(upper)
  @IsEnum(CommerceContentPublicationChannel)
  channel?: CommerceContentPublicationChannel;

  @IsOptional()
  @IsString()
  @Matches(/^[a-z][a-z0-9_:-]{2,63}$/)
  content_type?: string;

  @IsOptional()
  @IsUUID()
  author_id?: string;

  /** Filters the feed to boutique content, or to what shoppers have posted. */
  @IsOptional()
  @Transform(upper)
  @IsEnum(CommerceAuthorKind)
  author_kind?: CommerceAuthorKind;
}

export class ReactToContentDto {
  /**
   * Absent means the plain heart. Present means a story reaction, and the
   * glyph is stored verbatim because `my_reaction` in the story contract is
   * that exact string.
   */
  @IsOptional()
  @IsString()
  @Length(1, 8)
  emoji?: string;
}

export class CreateContentCommentDto {
  @IsString()
  @Length(1, 1000)
  body!: string;

  /**
   * One level only. A reply to a reply is re-parented to the thread root at
   * write time rather than refused — she was answering somebody, and telling
   * her the thread is too deep is a worse answer than placing her comment
   * where it can be read.
   */
  @IsOptional()
  @IsUUID()
  parent_id?: string;
}

export class ReshareContentDto {
  /** What she says about it. The only thing on a reshare that is hers. */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  /** Whose page she found it on, when it was not the original's. */
  @IsOptional()
  @IsUUID()
  via_reshare_id?: string;
}

export class ReportContentDto {
  @IsIn(CONTENT_REPORT_REASONS)
  reason!: (typeof CONTENT_REPORT_REASONS)[number];

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  detail?: string;
}

export class RemoveContentDto {
  /**
   * Mandatory, and long enough to be a sentence.
   *
   * The requirement is that removal is never silent and that the woman who
   * published it is told why — so the reason is demanded in three places: here,
   * in `ContentModerationService.remove`, and by a CHECK constraint on
   * `commerce_content_moderation_actions`. A rule enforced in one layer is a
   * rule with two ways around it.
   */
  @IsString()
  @MinLength(10)
  @MaxLength(500)
  reason!: string;
}

export class RemoveCommentDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class AdminContentQueryDto {
  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(100)
  limit: number = 25;

  get skip(): number {
    return (this.page - 1) * this.limit;
  }

  @IsOptional()
  @IsString()
  @Matches(/^[a-z][a-z0-9_:-]{2,63}$/)
  content_type?: string;

  @IsOptional()
  @Transform(upper)
  @IsEnum(CommerceAuthorKind)
  author_kind?: CommerceAuthorKind;

  @IsOptional()
  @Transform(upper)
  @IsEnum(CommerceContentStatus)
  status?: CommerceContentStatus;

  /** Only what somebody has complained about. */
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  reported?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  q?: string;
}

export class SetProfileVisibilityDto {
  /**
   * Opening her page: it becomes followable, and her content can reach a feed
   * beyond the women she has chosen.
   */
  @Type(() => Boolean)
  @IsBoolean()
  is_public!: boolean;
}
