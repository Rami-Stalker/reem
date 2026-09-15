/**
 * `iconv-lite`, as body-parser and raw-body use it on the edge.
 *
 * Express decodes request bodies through iconv-lite, which carries ~480 KB of
 * code-page tables. The runtime's own `TextDecoder` knows every encoding a
 * browser does, so the three calls the body parsers make are answered with it.
 */
function decoderFor(encoding: string): TextDecoder {
  return new TextDecoder(encoding === 'utf8' ? 'utf-8' : encoding);
}

function encodingExists(encoding: string): boolean {
  try {
    decoderFor(encoding);
    return true;
  } catch {
    return false;
  }
}

function decode(buffer: Uint8Array, encoding: string): string {
  return decoderFor(encoding).decode(buffer);
}

function getDecoder(encoding: string) {
  const decoder = decoderFor(encoding);
  return {
    write: (chunk: Uint8Array) => decoder.decode(chunk, { stream: true }),
    end: () => decoder.decode(),
  };
}

function encode(text: string): Buffer {
  return Buffer.from(text, 'utf8');
}

export = { encodingExists, decode, getDecoder, encode };
