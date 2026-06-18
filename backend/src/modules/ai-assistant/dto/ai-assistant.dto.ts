import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class AiRecommendationQueryDto {
  @IsOptional()
  @Type(() => Number)
  @Min(1)
  @Max(50)
  limit = 12;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  category?: string;

  @IsOptional()
  @IsBoolean()
  include_explanations?: boolean;
}

export class AiSuggestionQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  q?: string;

  @IsOptional()
  @Type(() => Number)
  @Min(1)
  @Max(20)
  limit = 8;
}

export class GenerateProductDescriptionDto {
  @IsOptional()
  @IsUUID()
  product_id?: string;

  @IsString()
  @MaxLength(140)
  title!: string;

  @IsString()
  @MaxLength(80)
  category!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  tone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  audience?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  attributes?: string[];
}

export class GenerateTagsDto {
  @IsOptional()
  @IsUUID()
  product_id?: string;

  @IsString()
  @MaxLength(140)
  title!: string;

  @IsString()
  @MaxLength(80)
  category!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1200)
  description?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  seed_tags?: string[];
}
