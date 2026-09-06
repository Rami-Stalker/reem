import { IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class SubmitPaymentReferenceDto {
  /**
   * The number the bank or the hawala office gave her. Kept loose on purpose —
   * every office formats these differently — but bounded, and free of the
   * whitespace and direction marks that a copy-paste from a receipt carries.
   */
  @IsString()
  @MinLength(3)
  @MaxLength(64)
  @Matches(/^[\w\u0600-\u06FF][\w\u0600-\u06FF\s\-/.]*$/u, {
    message: 'reference contains characters that are not part of a receipt number',
  })
  reference!: string;
}
