import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayNotEmpty,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { PolicyAudience } from '@prisma/client';

/** One language of one draft. Both are replaced wholesale on every save. */
export class PolicyTranslationDto {
  @IsString()
  @MaxLength(8)
  locale!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(200)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  summary?: string;

  /**
   * The body, in the restricted Markdown the app renders.
   *
   * The floor is deliberate. An empty body that somebody publishes by accident
   * is a policy page that says nothing while claiming to be the terms of use,
   * and a version cannot be edited once published — so the only way back from
   * it is a third version. Cheaper to refuse it here.
   */
  @IsString()
  @MinLength(50)
  @MaxLength(120_000)
  body!: string;
}

/**
 * `PATCH /admin/policies/:id` — the document's own settings.
 *
 * Its *text* is not here, and cannot be: text belongs to a version, and a
 * version that has been published is frozen. This endpoint only moves the
 * switches around the text — who must sign it, where it sits, whether it is
 * offered at all.
 */
export class UpdatePolicyDocumentDto {
  @IsOptional()
  @IsEnum(PolicyAudience)
  audience?: PolicyAudience;

  @IsOptional()
  @IsInt()
  @Min(0)
  sort_order?: number;

  @IsOptional()
  @IsBoolean()
  required_for_consent?: boolean;

  @IsOptional()
  @IsBoolean()
  is_active?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  icon?: string;
}

/**
 * `POST /admin/policies/:id/versions` — start a new draft.
 *
 * With no translations it clones the published version, which is what an
 * editor almost always wants: a policy is amended, not rewritten, and making
 * her paste ten thousand characters back in is how a clause goes missing.
 */
export class CreatePolicyVersionDto {
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(8)
  @ValidateNested({ each: true })
  @Type(() => PolicyTranslationDto)
  translations?: PolicyTranslationDto[];

  @IsOptional()
  @IsString()
  @MaxLength(400)
  change_note?: string;
}

/** `PATCH /admin/policies/versions/:id` — editing a draft. Drafts only. */
export class UpdatePolicyVersionDto {
  @IsOptional()
  @IsArray()
  @ArrayNotEmpty()
  @ArrayMaxSize(8)
  @ValidateNested({ each: true })
  @Type(() => PolicyTranslationDto)
  translations?: PolicyTranslationDto[];

  @IsOptional()
  @IsString()
  @MaxLength(400)
  change_note?: string;
}

/**
 * `POST /admin/policies/versions/:id/publish`.
 *
 * `requires_reacceptance` is the one field on this whole subsystem that costs
 * anything: true interrupts every account on that side of the marketplace at
 * next launch until it signs again. It is required rather than defaulted so
 * that publishing is always a decision about whether the change is material,
 * never an accident of whichever default somebody picked.
 */
export class PublishPolicyVersionDto {
  @IsBoolean()
  requires_reacceptance!: boolean;

  /** When the new terms bite. Defaults to now. */
  @IsOptional()
  @IsISO8601()
  effective_at?: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  change_note?: string;
}
