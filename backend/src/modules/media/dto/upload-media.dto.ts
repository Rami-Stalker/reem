import { MediaType, MediaVisibility } from '@prisma/client';
import { IsIn, IsOptional } from 'class-validator';

/**
 * What the upload is for.
 *
 * Visibility is derived from this rather than accepted from the client. Two
 * mistakes become impossible that way: a verification document cannot be
 * uploaded as public because a form field was wrong, and a product photograph
 * cannot be uploaded as private and then render as a broken image for every
 * shopper. The client says what it is doing; the server decides who may read
 * the result.
 *
 * `chat` is private for the same reason a conversation is: a photograph sent
 * to one seller is not addressed to anyone else. A public URL would be
 * unguessable but permanent — once it escaped, in a screenshot or a log, it
 * would stay readable by anyone who had it, forever. The readers of chat media
 * are the people in the chat, and that is a question only the server can
 * answer.
 */
export const MEDIA_PURPOSES = [
  'product',
  'post',
  'story',
  'avatar',
  'store_logo',
  'category',
  'verification',
  'chat',
] as const;

export type MediaPurpose = (typeof MEDIA_PURPOSES)[number];

const PRIVATE_PURPOSES = new Set<MediaPurpose>(['verification', 'chat']);

export function visibilityForPurpose(purpose: MediaPurpose): MediaVisibility {
  return PRIVATE_PURPOSES.has(purpose)
    ? MediaVisibility.PRIVATE
    : MediaVisibility.PUBLIC;
}

/**
 * What each purpose will accept.
 *
 * One function rather than a flag per kind, because the question is always the
 * same one — "what belongs here" — and a wrong answer is never cosmetic. A PDF
 * or a voice note where a product photograph belongs is a broken tile on every
 * card that shows the listing, and the client that uploaded it has no way to
 * find that out.
 *
 * `chat` takes a PDF now that `MessageKind.FILE` exists to describe one, a
 * bubble draws it, and the client fetches it with its session before handing
 * the bytes to the OS — a private URL cannot simply be opened in a browser.
 */
export function acceptedKinds(purpose: MediaPurpose): MediaType[] {
  switch (purpose) {
    case 'verification':
      return [MediaType.image, MediaType.document];
    case 'chat':
      return [MediaType.image, MediaType.audio, MediaType.document];
    default:
      return [MediaType.image, MediaType.video];
  }
}

export class UploadMediaDto {
  /**
   * Optional, defaulting to the most common case. A missing purpose must not
   * fail open into PRIVATE — an unreadable product image is a support ticket
   * on every listing — nor be inferred from the file, which says nothing about
   * intent.
   */
  @IsOptional()
  @IsIn(MEDIA_PURPOSES)
  purpose?: MediaPurpose;
}
