import assert from 'node:assert/strict';
import test from 'node:test';
import 'reflect-metadata';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaClient, UserRole } from '@prisma/client';

import { IS_PUBLIC_KEY } from '../../common/decorators/public.decorator';
import { MediaService } from '../media/media.service';
import { PrismaService } from '../../prisma/prisma.service';
import { UsersController } from './users.controller';
import { UsersRepository } from './users.repository';
import { UsersService } from './users.service';

/**
 * A profile page opened by someone who is not signed in.
 *
 * `GET /users/:id` demanded an account, so a visitor browsing as a guest got
 * an error on every boutique and shopper page she tapped — including the
 * shopfront a shared link lands on. And the follower lists carried each
 * person's phone number to whoever opened them.
 */

const prisma = new PrismaClient();

class Rollback extends Error {}
type Tx = Parameters<Parameters<typeof prisma.$transaction>[0]>[0];

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

function dbTest(name: string, body: (tx: Tx, users: UsersService) => Promise<void>) {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    let failure: unknown;
    try {
      await prisma.$transaction(
        async (tx) => {
          try {
            const db = tx as unknown as PrismaService;
            await body(
              tx,
              new UsersService(
                new UsersRepository(db),
                db,
                {} as MediaService,
                new EventEmitter2(),
              ),
            );
          } catch (error) {
            failure = error;
          }
          throw new Rollback();
        },
        { timeout: 60_000 },
      );
    } catch (error) {
      if (!(error instanceof Rollback)) throw error;
    }
    if (failure) throw failure;
  });
}

const uniq = (tag: string) =>
  `${tag}${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;

function makeUser(tx: Tx, tag: string, role: UserRole) {
  return tx.user.create({
    data: {
      name: `profile-${tag}`,
      username: `pp_${uniq(tag)}`,
      phone: `+9638${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role,
    },
  });
}

test('the profile routes are open to a visitor', () => {
  for (const handler of ['getProfile', 'followers', 'following'] as const) {
    assert.equal(
      Reflect.getMetadata(IS_PUBLIC_KEY, UsersController.prototype[handler]),
      true,
      `${handler} must not demand an account`,
    );
  }
});

dbTest('a visitor can open a boutique page', async (tx, users) => {
  const seller = await makeUser(tx, 's', UserRole.SELLER);
  const follower = await makeUser(tx, 'f', UserRole.CUSTOMER);
  await tx.follow.create({
    data: { followerId: follower.id, followingId: seller.id },
  });

  const page = (await users.getProfile(seller.id, undefined)) as Record<
    string,
    unknown
  >;

  assert.equal(page.id, seller.id);
  assert.equal(page.is_me, false);
  // A visitor follows nobody — not "whoever follows her".
  assert.equal(page.is_following, false);
  assert.equal(page.phone, undefined);
});

dbTest('follower lists never carry a phone number', async (tx, users) => {
  const seller = await makeUser(tx, 's', UserRole.SELLER);
  const follower = await makeUser(tx, 'f', UserRole.CUSTOMER);
  await tx.follow.create({
    data: { followerId: follower.id, followingId: seller.id },
  });

  const followers = (await users.listFollowers(seller.id)) as Record<
    string,
    unknown
  >[];
  const following = (await users.listFollowing(follower.id)) as Record<
    string,
    unknown
  >[];

  assert.deepEqual(
    followers.map((row) => row.id),
    [follower.id],
  );
  for (const row of [...followers, ...following]) {
    assert.equal(row.phone, undefined);
    assert.equal(row.email, undefined);
  }
});
