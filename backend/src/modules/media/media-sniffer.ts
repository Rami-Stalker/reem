import { MediaType } from '@prisma/client';

export interface SniffedMedia {
  mimeType: string;
  extension: string;
  kind: MediaType;
  width?: number;
  height?: number;
}

/**
 * What the bytes actually are.
 *
 * Neither the filename nor the `Content-Type` header is evidence — both are
 * written by the client, and "photo.jpg" containing HTML is the oldest stored-
 * XSS trick there is. Everything downstream (the extension on disk, the
 * `Content-Type` we serve back, the image/video split) is derived from this
 * function's answer and from nothing the caller said.
 *
 * The allow-list is short on purpose:
 *
 * - **SVG is refused.** It is an image everywhere in a product brief and a
 *   script host everywhere in a browser. Serving one from the platform's own
 *   origin hands an attacker same-origin JavaScript, which is session theft.
 * - **No zip, no HTML, no Office formats.** Nothing on the platform reads them.
 * - **MP4/QuickTime only for video**, because those are what phone cameras
 *   produce and what every client can play back without a transcoder.
 * - **PDF is recognised but not universally allowed.** A commercial register
 *   arrives as one often enough to be worth accepting, and a reviewer would
 *   rather have the original than a photograph of a screen. `MediaService`
 *   then refuses it for every purpose except the document ones, so it can only
 *   ever reach a private, staff-only endpoint — never a product card.
 * - **Audio, gated the same way.** M4A is what both phone platforms record to;
 *   MP3, Ogg and WAV are accepted because refusing a file the endpoint could
 *   obviously handle is its own kind of bug.
 */
export function sniffMedia(bytes: Buffer): SniffedMedia | null {
  if (bytes.length < 12) return null;

  if (isJpeg(bytes)) {
    return { mimeType: 'image/jpeg', extension: 'jpg', kind: MediaType.image, ...jpegSize(bytes) };
  }
  if (isPng(bytes)) {
    return { mimeType: 'image/png', extension: 'png', kind: MediaType.image, ...pngSize(bytes) };
  }
  if (isGif(bytes)) {
    return { mimeType: 'image/gif', extension: 'gif', kind: MediaType.image, ...gifSize(bytes) };
  }
  if (isWebp(bytes)) {
    return { mimeType: 'image/webp', extension: 'webp', kind: MediaType.image, ...webpSize(bytes) };
  }
  if (isMp4(bytes)) {
    return { mimeType: 'video/mp4', extension: 'mp4', kind: MediaType.video };
  }
  if (isQuickTime(bytes)) {
    return { mimeType: 'video/quicktime', extension: 'mov', kind: MediaType.video };
  }
  const audio = sniffAudio(bytes);
  if (audio) return audio;
  if (isPdf(bytes)) {
    return {
      mimeType: 'application/pdf',
      extension: 'pdf',
      kind: MediaType.document,
    };
  }
  return null;
}

// ── Signatures ──────────────────────────────────────────────────────────────

const isJpeg = (b: Buffer) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff;

const PNG_MAGIC = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const isPng = (b: Buffer) => b.subarray(0, 8).equals(PNG_MAGIC);

const isGif = (b: Buffer) =>
  b.subarray(0, 6).toString('latin1') === 'GIF87a' ||
  b.subarray(0, 6).toString('latin1') === 'GIF89a';

const isWebp = (b: Buffer) =>
  b.subarray(0, 4).toString('latin1') === 'RIFF' &&
  b.subarray(8, 12).toString('latin1') === 'WEBP';

/**
 * ISO base media: `....ftyp<brand>`. The brand list is the part that matters —
 * `ftyp` alone also covers formats nothing here can play, and `qt  ` is
 * QuickTime, which iPhones still hand over for some recordings.
 */
const MP4_BRANDS = new Set([
  'isom', 'iso2', 'iso4', 'iso5', 'iso6', 'mp41', 'mp42', 'avc1',
  'M4V ', 'dash', 'mmp4',
]);

/// The same ISO container with no video track. `M4A ` is what both phone
/// platforms write a voice note to, and it used to fall into the video list
/// above — which meant a ten-second recording was filed as a clip and held to
/// the 64 MB video ceiling.
const M4A_BRANDS = new Set(['M4A ', 'M4B ']);

const brandOf = (b: Buffer) =>
  b.subarray(4, 8).toString('latin1') === 'ftyp'
    ? b.subarray(8, 12).toString('latin1')
    : null;

const isMp4 = (b: Buffer) => {
  const brand = brandOf(b);
  return brand !== null && MP4_BRANDS.has(brand);
};

const isQuickTime = (b: Buffer) => brandOf(b) === 'qt  ';

// ── Audio ───────────────────────────────────────────────────────────────────

function sniffAudio(b: Buffer): SniffedMedia | null {
  const brand = brandOf(b);
  if (brand !== null && M4A_BRANDS.has(brand)) {
    return { mimeType: 'audio/mp4', extension: 'm4a', kind: MediaType.audio };
  }
  if (b.subarray(0, 4).toString('latin1') === 'OggS') {
    return { mimeType: 'audio/ogg', extension: 'ogg', kind: MediaType.audio };
  }
  if (isWav(b)) {
    return { mimeType: 'audio/wav', extension: 'wav', kind: MediaType.audio };
  }
  if (isMp3(b)) {
    return { mimeType: 'audio/mpeg', extension: 'mp3', kind: MediaType.audio };
  }
  return null;
}

const isWav = (b: Buffer) =>
  b.subarray(0, 4).toString('latin1') === 'RIFF' &&
  b.subarray(8, 12).toString('latin1') === 'WAVE';

/// Either an ID3 tag or a bare frame header. The second form is why the version
/// and layer bits are checked rather than only the sync word: `FF Ex` alone
/// occurs in plenty of files that are not MP3s.
const isMp3 = (b: Buffer) => {
  if (b.subarray(0, 3).toString('latin1') === 'ID3') return true;
  if (b[0] !== 0xff || (b[1] & 0xe0) !== 0xe0) return false;
  const version = (b[1] >> 3) & 0x03;
  const layer = (b[1] >> 1) & 0x03;
  return version !== 0x01 && layer !== 0x00; // reserved values
};

/// `%PDF-` and a version digit. The header is allowed to sit a little way into
/// the file by the specification, and real-world writers do it, so the first
/// kilobyte is searched rather than only offset zero.
const isPdf = (b: Buffer) => {
  const at = b.subarray(0, 1024).indexOf('%PDF-', 0, 'latin1');
  if (at === -1) return false;
  const version = b[at + 5];
  return version >= 0x31 && version <= 0x39; // %PDF-1.x … %PDF-9.x
};

// ── Dimensions ──────────────────────────────────────────────────────────────
//
// Read from the container's own header rather than by decoding the image. A
// decoder is a large attack surface and a native dependency; a header read is
// forty lines and cannot execute anything. Videos are left undecided — their
// dimensions live behind a box walk that would not earn its complexity here.

type Size = { width?: number; height?: number };

function pngSize(b: Buffer): Size {
  // IHDR is mandatory and always the first chunk: 8 magic + 4 length + 4 type.
  if (b.length < 24) return {};
  return { width: b.readUInt32BE(16), height: b.readUInt32BE(20) };
}

function gifSize(b: Buffer): Size {
  if (b.length < 10) return {};
  return { width: b.readUInt16LE(6), height: b.readUInt16LE(8) };
}

/** Walk the JPEG segment chain to the frame header. */
function jpegSize(b: Buffer): Size {
  let offset = 2;
  while (offset + 9 < b.length) {
    if (b[offset] !== 0xff) return {};

    // Fill bytes: a marker may be preceded by any number of 0xFF.
    let marker = b[offset + 1];
    let cursor = offset + 1;
    while (marker === 0xff && cursor + 1 < b.length) {
      cursor += 1;
      marker = b[cursor];
    }

    // SOF0..SOF15, excluding DHT (0xC4), JPG (0xC8) and DAC (0xCC), which
    // share the range but are not frame headers.
    const isFrameHeader =
      marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
    if (isFrameHeader) {
      const sof = cursor + 1;
      if (sof + 6 >= b.length) return {};
      return { height: b.readUInt16BE(sof + 3), width: b.readUInt16BE(sof + 5) };
    }

    // Standalone markers carry no length payload.
    if (marker === 0xd8 || (marker >= 0xd0 && marker <= 0xd9)) {
      offset = cursor + 1;
      continue;
    }
    if (cursor + 3 >= b.length) return {};
    const length = b.readUInt16BE(cursor + 1);
    if (length < 2) return {};
    offset = cursor + 1 + length;
  }
  return {};
}

/** Three sub-formats hide behind the same RIFF/WEBP header. */
function webpSize(b: Buffer): Size {
  const chunk = b.subarray(12, 16).toString('latin1');

  if (chunk === 'VP8 ' && b.length >= 30) {
    return {
      width: b.readUInt16LE(26) & 0x3fff,
      height: b.readUInt16LE(28) & 0x3fff,
    };
  }
  if (chunk === 'VP8L' && b.length >= 25) {
    const bits = b.readUInt32LE(21);
    return {
      width: (bits & 0x3fff) + 1,
      height: ((bits >> 14) & 0x3fff) + 1,
    };
  }
  if (chunk === 'VP8X' && b.length >= 30) {
    return {
      width: b.readUIntLE(24, 3) + 1,
      height: b.readUIntLE(27, 3) + 1,
    };
  }
  return {};
}
