import assert from 'node:assert/strict';
import test from 'node:test';
import {
  PrismaClient,
  StoreTeamRole,
  StoreTeamStatus,
  UserRole,
} from '@prisma/client';

import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../../prisma/prisma.service';
import { SellerStoreService } from './seller-store.service';
import { StoreDelegationGuard } from './store-delegation.guard';

/**
 * The shop's own settings and its team: an invitation must be answered from
 * the member's account before she can act, her access follows her role, and
 * the owner's activity log names who did what.
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
test.after(() => prisma.$disconnect());

function asPrisma(tx: Tx): PrismaService {
  return new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: (inner: Tx) => unknown) => fn(tx);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

const notified: { userId: string; title: string }[] = [];
const notifications = {
  notifyAccount: async (input: { userId: string; title: string }) => {
    notified.push(input);
  },
} as unknown as NotificationsService;

function dbTest(name: string, body: (tx: Tx) => Promise<void>): void {
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
            await body(tx);
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

let counter = 0;
const phone = () =>
  `+9639${String(Math.floor(10000000 + Math.random() * 89999999))}`;
const user = (tx: Tx, role: UserRole) =>
  tx.user.create({
    data: {
      name: role === UserRole.SELLER ? 'بوتيك اختبار' : 'عضوة اختبار',
      phone: phone(),
      username: `team_spec_${Date.now().toString(36)}${(counter += 1)}`,
      role,
      ...(role === UserRole.SELLER && { sellerVerifiedAt: new Date() }),
    },
  });

function request(path: string, userId: string, storeId?: string) {
  return {
    path,
    headers: storeId ? { 'x-ohara-store': storeId } : {},
    user: { id: userId, phone: null, role: UserRole.CUSTOMER, sessionId: 's' },
  } as unknown as Record<string, unknown>;
}

function context(req: Record<string, unknown>) {
  return {
    getType: () => 'http',
    switchToHttp: () => ({ getRequest: () => req }),
  } as never;
}

dbTest('an invitation must be accepted before she can act for the shop', async (tx) => {
  const db = asPrisma(tx);
  const store = new SellerStoreService(db, notifications);
  const guard = new StoreDelegationGuard(db);
  const owner = await user(tx, UserRole.SELLER);
  const member = await user(tx, UserRole.CUSTOMER);

  const invited = await store.invite(owner.id, {
    phone: member.phone!,
    role: StoreTeamRole.ORDERS,
  });
  assert.equal(invited?.status, 'invited');
  assert.ok(notified.some((n) => n.userId === member.id));

  // Not yet: an invitation is not access.
  await assert.rejects(() =>
    guard.canActivate(context(request('/seller/orders', member.id, owner.id))),
  );

  await store.respond(member.id, invited!.id, true);
  const req = request('/seller/orders', member.id, owner.id);
  assert.equal(await guard.canActivate(context(req)), true);
  assert.equal((req.user as { id: string }).id, owner.id, 'runs as the shop');
  assert.equal(
    (req.storeActor as { memberId: string }).memberId,
    member.id,
    'and remembers who she is',
  );

  // Her role covers orders, not money.
  await assert.rejects(() =>
    guard.canActivate(
      context(request('/finance/seller/earnings', member.id, owner.id)),
    ),
  );

  // Removed, she is out.
  await store.remove(owner.id, invited!.id);
  const row = await tx.sellerTeamMember.findUniqueOrThrow({
    where: { id: invited!.id },
  });
  assert.equal(row.status, StoreTeamStatus.REMOVED);
  await assert.rejects(() =>
    guard.canActivate(context(request('/seller/orders', member.id, owner.id))),
  );
});

dbTest('only a personal account can be invited, and only once', async (tx) => {
  const store = new SellerStoreService(asPrisma(tx), notifications);
  const owner = await user(tx, UserRole.SELLER);
  const otherShop = await user(tx, UserRole.SELLER);
  const member = await user(tx, UserRole.CUSTOMER);

  await assert.rejects(() =>
    store.invite(owner.id, { phone: '+963999999999', role: StoreTeamRole.ORDERS }),
  );
  await assert.rejects(() =>
    store.invite(owner.id, { phone: otherShop.phone!, role: StoreTeamRole.ORDERS }),
  );
  await store.invite(owner.id, { phone: member.phone!, role: StoreTeamRole.CATALOG });
  await assert.rejects(() =>
    store.invite(owner.id, { phone: member.phone!, role: StoreTeamRole.ORDERS }),
  );
});

dbTest('the activity log shows the shop’s own writes and her team’s', async (tx) => {
  const store = new SellerStoreService(asPrisma(tx), notifications);
  const owner = await user(tx, UserRole.SELLER);
  const member = await user(tx, UserRole.CUSTOMER);
  await tx.auditLog.createMany({
    data: [
      { actorId: owner.id, action: 'login', category: 'auth', outcome: 'success' },
      {
        actorId: member.id,
        action: 'POST /seller/orders/:id/confirm',
        category: 'seller',
        outcome: 'SUCCESS',
        metadata: { store_id: owner.id },
      },
      // Someone else's shop: never shown.
      {
        actorId: member.id,
        action: 'POST /seller/orders/:id/confirm',
        category: 'seller',
        outcome: 'SUCCESS',
        metadata: { store_id: member.id },
      },
    ],
  });

  const page = await store.activity(owner.id, {});
  assert.equal(page.data.length, 2);
  const team = page.data.find((entry) => entry.via_team);
  assert.equal(team?.actor?.id, member.id);
  assert.equal(team?.actor?.is_owner, false);
});

dbTest('a new listing starts with the shop’s preparation time', async (tx) => {
  const store = new SellerStoreService(asPrisma(tx), notifications);
  const owner = await user(tx, UserRole.SELLER);
  assert.equal(await store.defaultHandlingDays(owner.id), 1);
  await store.updateShipping(owner.id, { default_handling_days: 3 });
  assert.equal(await store.defaultHandlingDays(owner.id), 3);

  const info = await store.publicInfo(owner.id);
  assert.equal(info.shipping.default_handling_days, 3);
  assert.equal(info.policies.platform_return_days, 7);
});
