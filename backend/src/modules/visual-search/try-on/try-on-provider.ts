/** DI token for the virtual try-on renderer, if one is ever configured. */
export const TRY_ON_PROVIDER = Symbol('TRY_ON_PROVIDER');

export interface TryOnRenderInput {
  /** Her photograph. Re-encoded and EXIF-stripped, like every other upload. */
  person: Buffer;
  personMimeType: string;

  /** The garment's own photograph, from the catalogue. */
  garment: Buffer;
  garmentMimeType: string;

  /** Enough to let a provider pick the right rendering mode. */
  garment_hint: {
    categorySlug: string;
    slot: string | null;
    title: string;
  };
}

export type TryOnRenderResult =
  | {
      status: 'READY';
      /** The rendered image, as bytes. Stored as a PRIVATE asset by the caller. */
      image: Buffer;
      mimeType: string;
    }
  | {
      status: 'PROCESSING';
      /** The provider's handle, polled later. */
      externalId: string;
    }
  | {
      status: 'FAILED';
      /** Machine-readable, recorded on the row. */
      code: string;
    };

/**
 * The seam a virtual try-on service plugs into.
 *
 * ── Why there is no implementation in this repository ────────────────────
 *
 * Because there is no honest one. Putting a dress onto a photograph of a
 * particular woman's body is a generative task: it needs a diffusion model
 * trained for garment transfer, it needs a GPU, and there is no arrangement of
 * `sharp` calls that approximates it. The alternatives available without such
 * a model are all forms of lying to her — overlaying a cut-out at a guessed
 * scale, showing the garment beside her instead of on her, or displaying a
 * stock model and calling it a preview — and every one of them would be worse
 * than the honest answer, which is "لسا ما توفرت".
 *
 * So what exists here is the whole feature *except* the renderer:
 *
 *  - the consent record, per request, because consenting to one try-on is not
 *    consenting to the next;
 *  - the retention clock, the shortest in the schema, because the input is a
 *    photograph of her body;
 *  - the private storage path, on which no reader but she is authorised —
 *    see `MediaService.mayRead`, where `try_on` returns false for everyone;
 *  - the status machine, including the honest `UNAVAILABLE` terminal state;
 *  - the API surface, which reports the capability as off so the client can
 *    render the entry point accordingly rather than discovering it at the
 *    moment she taps.
 *
 * Adding a provider is therefore one class and one line of configuration, with
 * no schema change, no new endpoint and no client release.
 */
export interface TryOnProvider {
  /** Recorded on `visual_try_on_requests.provider`. */
  readonly name: string;
  readonly enabled: boolean;

  render(input: TryOnRenderInput): Promise<TryOnRenderResult>;

  /** Polled for a provider that renders asynchronously. */
  poll?(externalId: string): Promise<TryOnRenderResult>;
}

/**
 * The default, and the only implementation today.
 *
 * It refuses, in one place, with one code. Every caller therefore has exactly
 * one path and the "no provider" case is the one under test rather than a
 * branch beside it.
 */
export class DisabledTryOnProvider implements TryOnProvider {
  readonly name = 'none';
  readonly enabled = false;

  async render(): Promise<TryOnRenderResult> {
    return { status: 'FAILED', code: 'NO_PROVIDER' };
  }
}
