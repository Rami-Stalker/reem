import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import { MediaType } from '@prisma/client';
import test from 'node:test';
import { sniffMedia } from './media-sniffer';

// ── Builders ────────────────────────────────────────────────────────────────

function png(width: number, height: number): Buffer {
  const buffer = Buffer.alloc(24);
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(buffer, 0);
  buffer.writeUInt32BE(13, 8);
  buffer.write('IHDR', 12, 'latin1');
  buffer.writeUInt32BE(width, 16);
  buffer.writeUInt32BE(height, 20);
  return buffer;
}

/** SOI, a JFIF APP0 segment, then the SOF0 frame header the parser walks to. */
function jpeg(width: number, height: number): Buffer {
  const buffer = Buffer.alloc(40);
  buffer.writeUInt16BE(0xffd8, 0);
  buffer.writeUInt16BE(0xffe0, 2);
  buffer.writeUInt16BE(0x0010, 4);
  buffer.write('JFIF\0', 6, 'latin1');
  buffer.writeUInt16BE(0xffc0, 20);
  buffer.writeUInt16BE(0x0011, 22);
  buffer.writeUInt8(8, 24);
  buffer.writeUInt16BE(height, 25);
  buffer.writeUInt16BE(width, 27);
  return buffer;
}

function gif(width: number, height: number): Buffer {
  const buffer = Buffer.alloc(16);
  buffer.write('GIF89a', 0, 'latin1');
  buffer.writeUInt16LE(width, 6);
  buffer.writeUInt16LE(height, 8);
  return buffer;
}

function webpLossy(width: number, height: number): Buffer {
  const buffer = Buffer.alloc(32);
  buffer.write('RIFF', 0, 'latin1');
  buffer.write('WEBP', 8, 'latin1');
  buffer.write('VP8 ', 12, 'latin1');
  buffer.writeUInt16LE(width, 26);
  buffer.writeUInt16LE(height, 28);
  return buffer;
}

function webpExtended(width: number, height: number): Buffer {
  const buffer = Buffer.alloc(32);
  buffer.write('RIFF', 0, 'latin1');
  buffer.write('WEBP', 8, 'latin1');
  buffer.write('VP8X', 12, 'latin1');
  buffer.writeUIntLE(width - 1, 24, 3);
  buffer.writeUIntLE(height - 1, 27, 3);
  return buffer;
}

function isoMedia(brand: string): Buffer {
  const buffer = Buffer.alloc(32);
  buffer.writeUInt32BE(32, 0);
  buffer.write('ftyp', 4, 'latin1');
  buffer.write(brand, 8, 'latin1');
  return buffer;
}

// ── Recognition ─────────────────────────────────────────────────────────────

test('a JPEG is recognised and measured from its frame header', () => {
  assert.deepEqual(sniffMedia(jpeg(1200, 800)), {
    mimeType: 'image/jpeg',
    extension: 'jpg',
    kind: 'image',
    width: 1200,
    height: 800,
  });
});

test('a PNG is measured from IHDR', () => {
  const sniffed = sniffMedia(png(64, 128));
  assert.equal(sniffed?.mimeType, 'image/png');
  assert.equal(sniffed?.width, 64);
  assert.equal(sniffed?.height, 128);
});

test('a GIF stores its dimensions little-endian', () => {
  const sniffed = sniffMedia(gif(300, 200));
  assert.equal(sniffed?.mimeType, 'image/gif');
  assert.equal(sniffed?.width, 300);
  assert.equal(sniffed?.height, 200);
});

test('a lossy WebP masks off the two high bits of each dimension', () => {
  const sniffed = sniffMedia(webpLossy(640, 480));
  assert.equal(sniffed?.mimeType, 'image/webp');
  assert.equal(sniffed?.width, 640);
  assert.equal(sniffed?.height, 480);
});

test('an extended WebP stores each dimension minus one, in three bytes', () => {
  const sniffed = sniffMedia(webpExtended(4096, 2160));
  assert.equal(sniffed?.width, 4096);
  assert.equal(sniffed?.height, 2160);
});

test('an MP4 is video, and its dimensions are left undecided', () => {
  const sniffed = sniffMedia(isoMedia('isom'));
  assert.equal(sniffed?.mimeType, 'video/mp4');
  assert.equal(sniffed?.kind, 'video');
  assert.equal(sniffed?.width, undefined);
});

test('QuickTime is recognised — iPhones still hand it over', () => {
  assert.equal(sniffMedia(isoMedia('qt  '))?.mimeType, 'video/quicktime');
});

test('an M4A is audio, not a video clip', () => {
  // It shares the ISO container with MP4 and used to fall into the video
  // branch, which filed a ten-second voice note as a clip and held it to the
  // 64 MB video ceiling.
  const sniffed = sniffMedia(isoMedia('M4A '));
  assert.equal(sniffed?.mimeType, 'audio/mp4');
  assert.equal(sniffed?.kind, 'audio');
  assert.equal(sniffed?.extension, 'm4a');
});

test('an actual MP4 is still a video', () => {
  assert.equal(sniffMedia(isoMedia('mp42'))?.kind, 'video');
});

test('Ogg, WAV and MP3 are recognised', () => {
  const ogg = Buffer.alloc(16);
  ogg.write('OggS', 0, 'latin1');
  assert.equal(sniffMedia(ogg)?.mimeType, 'audio/ogg');

  const wav = Buffer.alloc(16);
  wav.write('RIFF', 0, 'latin1');
  wav.write('WAVE', 8, 'latin1');
  assert.equal(sniffMedia(wav)?.mimeType, 'audio/wav');

  const id3 = Buffer.alloc(16);
  id3.write('ID3', 0, 'latin1');
  assert.equal(sniffMedia(id3)?.mimeType, 'audio/mpeg');
});

test('a bare MP3 frame header is accepted, a reserved one is not', () => {
  const frame = Buffer.alloc(16);
  frame.writeUInt8(0xff, 0);
  frame.writeUInt8(0xfb, 1); // MPEG-1 layer III
  assert.equal(sniffMedia(frame)?.mimeType, 'audio/mpeg');

  const reserved = Buffer.alloc(16);
  reserved.writeUInt8(0xff, 0);
  reserved.writeUInt8(0xe9, 1); // reserved layer — `FF Ex` alone is not enough
  assert.equal(sniffMedia(reserved), null);
});

// ── Refusal ─────────────────────────────────────────────────────────────────

test('SVG is refused, however plausible the filename was', () => {
  const svg = Buffer.from(
    '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>',
  );
  // It is an image in every product brief and a script host in every browser.
  // Served from this platform's own origin it would be same-origin JavaScript.
  assert.equal(sniffMedia(svg), null);
});

test('HTML wearing a .jpg name is refused', () => {
  assert.equal(sniffMedia(Buffer.from('<!DOCTYPE html><html>hello</html>')), null);
});

test('a PDF is recognised as a document, not an image', () => {
  // Recognised here; whether it is *allowed* is the purpose's business, and
  // `MediaService` refuses one for every purpose but the document ones.
  assert.deepEqual(sniffMedia(Buffer.from('%PDF-1.7\n%aaaaaaaa\n')), {
    mimeType: 'application/pdf',
    extension: 'pdf',
    kind: 'document',
  });
});

test('a PDF header a little way into the file is still found', () => {
  // The specification permits leading bytes and real writers emit them.
  const buffer = Buffer.concat([
    Buffer.alloc(200, 0x20),
    Buffer.from('%PDF-1.4\n'),
  ]);
  assert.equal(sniffMedia(buffer)?.mimeType, 'application/pdf');
});

test('prose that merely mentions %PDF- is not a PDF', () => {
  assert.equal(sniffMedia(Buffer.from('see the %PDF-x spec for details')), null);
});

test('an ISO container whose brand nothing can play is refused', () => {
  assert.equal(sniffMedia(isoMedia('heic')), null);
});

test('a truncated file is refused rather than half-read', () => {
  assert.equal(sniffMedia(Buffer.from([0xff, 0xd8, 0xff])), null);
});

test('a JPEG magic number followed by rubbish yields no dimensions', () => {
  const buffer = Buffer.alloc(32);
  buffer.writeUInt16BE(0xffd8, 0);
  buffer.writeUInt8(0xff, 2);
  buffer.writeUInt8(0xe0, 3);
  buffer.writeUInt16BE(0x0002, 4); // a segment that advances but never frames
  const sniffed = sniffMedia(buffer);
  assert.equal(sniffed?.mimeType, 'image/jpeg');
  assert.equal(sniffed?.width, undefined);
  assert.equal(sniffed?.height, undefined);
});

// ── Real recordings ─────────────────────────────────────────────────────────
// Encoded with ffmpeg the way each phone writes them: Android's recorder puts
// AAC in an MP4 box with the generic `mp42` brand, iOS writes `M4A `.

const fixture = (name: string) =>
  readFileSync(join(__dirname, '__fixtures__', name));

test('an Android voice note — AAC under a generic MP4 brand — is audio', () => {
  const sniffed = sniffMedia(fixture('voice-android.m4a'));
  assert.equal(sniffed?.kind, MediaType.audio);
  assert.equal(sniffed?.mimeType, 'audio/mp4');
});

test('an iPhone voice note is audio', () => {
  assert.equal(sniffMedia(fixture('voice-ios.m4a'))?.kind, MediaType.audio);
});

test('a clip with a picture track is still a video', () => {
  assert.equal(sniffMedia(fixture('clip.mp4'))?.kind, MediaType.video);
});
