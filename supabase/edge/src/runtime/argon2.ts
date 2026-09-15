/**
 * `argon2`, as the backend sees it on the edge.
 *
 * The native `argon2` package is a compiled Node addon and cannot load in an
 * isolate. This module implements the three members the backend uses —
 * `hash`, `verify` and the `argon2id` type constant — on hash-wasm's
 * WebAssembly Argon2. Output is the standard PHC string
 * (`$argon2id$v=19$m=…,t=…,p=…$salt$hash`), so hashes written by the server
 * build verify here and hashes written here verify on the server build.
 */
import { randomBytes } from 'node:crypto';
import { argon2id as argon2idHash, argon2Verify } from 'hash-wasm';

export const argon2d = 0;
export const argon2i = 1;
export const argon2id = 2;

export interface Options {
  type?: number;
  memoryCost?: number;
  timeCost?: number;
  parallelism?: number;
  hashLength?: number;
  saltLength?: number;
}

export async function hash(plain: string | Buffer, options: Options = {}): Promise<string> {
  if (options.type !== undefined && options.type !== argon2id) {
    throw new Error('Only argon2id is available on the edge runtime');
  }
  return argon2idHash({
    password: plain,
    salt: randomBytes(options.saltLength ?? 16),
    // node-argon2's defaults, so an options object that omits a field hashes
    // identically on both builds.
    memorySize: options.memoryCost ?? 65536,
    iterations: options.timeCost ?? 3,
    parallelism: options.parallelism ?? 4,
    hashLength: options.hashLength ?? 32,
    outputType: 'encoded',
  });
}

export async function verify(digest: string, plain: string | Buffer): Promise<boolean> {
  try {
    return await argon2Verify({ password: plain, hash: digest });
  } catch {
    return false;
  }
}

export function needsRehash(): boolean {
  return false;
}
