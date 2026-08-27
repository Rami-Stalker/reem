import {
  IsBoolean,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class RegisterContentTypeDto {
  @IsString()
  @Matches(/^[a-z][a-z0-9_:-]{2,63}$/)
  key!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @IsObject()
  schema!: Record<string, unknown>;

  @IsOptional()
  @IsObject()
  ui_schema?: Record<string, unknown>;

  @IsOptional()
  @IsObject()
  capabilities?: Record<string, unknown>;

  @IsOptional()
  @IsObject()
  lifecycle?: Record<string, unknown>;

  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10_000)
  version?: number;
}
