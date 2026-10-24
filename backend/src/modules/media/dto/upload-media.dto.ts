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
  'visual_search',
  'try_on',
  'closet',
  'return_evidence',
  'review',
] as const;

export type MediaPurpose = (typeof MEDIA_PURPOSES)[number];

/**
 * `visual_search` and `try_on` are private for a reason neither of the other
 * two has. A verification document is sensitive because of what it proves; a
 * chat photograph because of who it was addressed to. These are sensitive
 * because of what they *are*: a screenshot from her own phone, and — in the
 * try-on case — a photograph of her body. Both are also the only two purposes
 * on a retention clock, deleted by `VisualRetentionService` once the search
 * they served is over. Nothing else in the schema deletes a photograph the
 * uploader never asked to delete.
 *
 * `closet` joins them on the same reasoning and differs on the clock. A woman
 * photographing her own wardrobe is photographing her bedroom, her mirror and
 * frequently herself, and the resulting picture is the single most private
 * thing she can put into this application — so PRIVATE is not a judgement call.
 * It is *not* on a retention clock, because unlike a search photograph this one
 * is the permanent illustration of something she owns: deleting it would empty
 * a tile in her own wardrobe. It goes when she deletes the piece.
 */
/**
 * `return_evidence` is deliberately *not* here, and that is a judgement worth
 * stating rather than leaving to be inferred from an omission.
 *
 * A return photograph has three legitimate readers from the moment it is
 * taken — the shopper, the boutique she is claiming against, and whoever
 * arbitrates if they disagree — so the owner-only rule the private purposes
 * rest on does not describe it. Making it private would mean inventing a
 * fourth `mayRead` branch that resolves an asset back to the return it is
 * attached to, and `ReturnRequest.evidence` holds URLs rather than asset ids,
 * so there is nothing to resolve through. The seller's return desk already
 * renders these as plain image URLs.
 *
 * What protects them is the same thing that protects a product photograph: an
 * unguessable key that is never listed. If returns evidence should be narrower
 * than that, the change is a real one — an asset-id column on the return, and
 * a `mayRead` branch for the parties to it — not a line added to this set.
 */
const PRIVATE_PURPOSES = new Set<MediaPurpose>([
  'verification',
  'chat',
  'visual_search',
  'try_on',
  'closet',
]);

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
    case 'visual_search':
    case 'try_on':
      // Images only, and deliberately narrower than the default: there is no
      // reading of "search by video" or "try this on a clip of me" that this
      // pipeline can honour, and accepting one would store a file nothing will
      // ever look at.
      return [MediaType.image];
    case 'closet':
      // Images only, for the same reason: a closet tile draws a photograph, and
      // a video of a garment has nowhere to play.
      return [MediaType.image];
    case 'return_evidence':
      // A photograph of the fault, which `POST /returns` requires before it
      // will move money away from a seller. Stills only: a reviewer comparing
      // a torn seam against a listing photograph is looking, not watching.
      return [MediaType.image];
    case 'review':
      // A photograph of the piece, under «تقييمات من بمقاسي». The composer asks
      // for the piece itself, not her in it. Public, and moderated with the
      // review it belongs to. Stills only: a review card draws a
      // strip of thumbnails, and a clip has nowhere to play.
      return [MediaType.image];
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
