import {
  IsEnum,
  IsISO8601,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { ExperimentStatus } from '@prisma/client';

export class CreateExperimentDto {
  /**
   * Lowercase, stable, and part of the assignment hash — renaming it
   * re-randomises everybody, which is what starting a new test means.
   */
  @IsString()
  @MinLength(3)
  @MaxLength(60)
  @Matches(/^[a-z0-9_]+$/, {
    message: 'key must be lowercase letters, digits and underscores',
  })
  key!: string;

  @IsString()
  @MaxLength(120)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  hypothesis?: string;

  /** What counts as success — matched against the metric on a conversion. */
  @IsString()
  @MaxLength(60)
  metric!: string;

  /** `[{ "key": "control", "weight": 50 }, { "key": "b", "weight": 50 }]` */
  variants!: unknown;

  @IsISO8601()
  starts_at!: string;

  @IsOptional()
  @IsISO8601()
  ends_at?: string;
}

export class SetExperimentStatusDto {
  @IsEnum(ExperimentStatus)
  status!: ExperimentStatus;
}

export class RecordExperimentEventDto {
  @IsString()
  @MaxLength(60)
  key!: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  metric?: string;
}
