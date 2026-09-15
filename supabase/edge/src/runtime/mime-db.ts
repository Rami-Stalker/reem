/**
 * `mime-db`, trimmed to the types this API sends and receives.
 *
 * Express consults it (through `mime-types`) to match `Content-Type` headers
 * and to pick a type for `res.type()`. The full database is ~130 KB; the API
 * speaks JSON, form posts, multipart uploads and the media types its sniffer
 * accepts.
 */
const db: Record<string, { source?: string; charset?: string; compressible?: boolean; extensions?: string[] }> = {
  'application/json': { source: 'iana', charset: 'UTF-8', compressible: true, extensions: ['json', 'map'] },
  'application/x-www-form-urlencoded': { source: 'iana', compressible: true },
  'application/octet-stream': { source: 'iana', compressible: false, extensions: ['bin'] },
  'application/pdf': { source: 'iana', compressible: false, extensions: ['pdf'] },
  'application/javascript': { source: 'iana', charset: 'UTF-8', compressible: true, extensions: ['js', 'mjs'] },
  'application/wasm': { source: 'iana', compressible: true, extensions: ['wasm'] },
  'multipart/form-data': { source: 'iana' },
  'text/plain': { source: 'iana', compressible: true, extensions: ['txt', 'text'] },
  'text/html': { source: 'iana', compressible: true, extensions: ['html', 'htm'] },
  'text/csv': { source: 'iana', compressible: true, extensions: ['csv'] },
  'image/jpeg': { source: 'iana', compressible: false, extensions: ['jpeg', 'jpg', 'jpe'] },
  'image/png': { source: 'iana', compressible: false, extensions: ['png'] },
  'image/gif': { source: 'iana', compressible: false, extensions: ['gif'] },
  'image/webp': { source: 'apache', extensions: ['webp'] },
  'image/heic': { source: 'iana', extensions: ['heic'] },
  'image/svg+xml': { source: 'iana', compressible: true, extensions: ['svg', 'svgz'] },
  'video/mp4': { source: 'iana', compressible: false, extensions: ['mp4', 'mp4v', 'mpg4'] },
  'video/quicktime': { source: 'iana', compressible: false, extensions: ['qt', 'mov'] },
  'video/webm': { source: 'apache', compressible: false, extensions: ['webm'] },
  'audio/mp4': { source: 'iana', compressible: false, extensions: ['m4a', 'mp4a'] },
  'audio/mpeg': { source: 'iana', compressible: false, extensions: ['mpga', 'mp2', 'mp2a', 'mp3', 'm2a', 'm3a'] },
  'audio/ogg': { source: 'iana', compressible: false, extensions: ['oga', 'ogg', 'spx', 'opus'] },
  'audio/wav': { compressible: false, extensions: ['wav'] },
};

export = db;
