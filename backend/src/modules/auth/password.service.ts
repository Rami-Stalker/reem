import { Injectable } from '@nestjs/common';
import * as argon2 from 'argon2';
import * as bcrypt from 'bcryptjs';

@Injectable()
export class PasswordService {
  private readonly rounds = 12;
  private readonly argon2Options = {
    type: argon2.argon2id,
    memoryCost: 64 * 1024,
    timeCost: 3,
    parallelism: 1,
  } satisfies argon2.Options;

  hash(plain: string): Promise<string> {
    return argon2.hash(plain, this.argon2Options);
  }

  async verify(plain: string, hash: string): Promise<boolean> {
    if (hash.startsWith('$argon2id$')) {
      return argon2.verify(hash, plain);
    }
    if (hash.startsWith('$2a$') || hash.startsWith('$2b$') || hash.startsWith('$2y$')) {
      return bcrypt.compare(plain, hash);
    }
    return false;
  }

  needsRehash(hash: string): boolean {
    return !hash.startsWith('$argon2id$');
  }
}
