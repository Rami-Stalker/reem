import { IsString, MaxLength, MinLength } from 'class-validator';

export class ReactStoryDto {
  /** A single emoji (kept short to allow multi-codepoint glyphs). */
  @IsString()
  @MinLength(1)
  @MaxLength(8)
  emoji!: string;
}
