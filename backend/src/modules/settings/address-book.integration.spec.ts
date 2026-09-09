import assert from 'node:assert/strict';
import test from 'node:test';
import { PrismaClient, UserRole } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { SettingsService } from './settings.service';

/**
 * The address book, which until now could not fill a single checkout field.
 *
 * The tests are about the two things a book of addresses has to get right —
 * exactly one default at any moment, and never showing one woman another's —
 * because everything else about it is a form.
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

function dbTest(name: string, body: (world: World) => Promise<void>): void {
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
            await body({ tx, settings: build(tx) });
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

interface World {
  tx: Tx;
  settings: SettingsService;
}

function build(tx: Tx): SettingsService {
  const db = new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: (inner: Tx) => unknown) => fn(tx);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
  return new SettingsService(db);
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;

async function makeUser(tx: Tx, tag: string) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `addr-${tag}`,
      username: `addr_${u}`,
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role: UserRole.CUSTOMER,
    },
  });
}

const damascus = {
  recipient_name: 'ريم الدالي',
  recipient_phone: '+963900111222',
  governorate: 'دمشق',
  district: 'المزة',
  city: 'دمشق',
  address_line: 'شارع الجلاء، بناء 12',
  landmark: 'قرب الصيدلية',
};

const aleppo = {
  recipient_name: 'ليلى الحسن',
  recipient_phone: '+963900333444',
  governorate: 'حلب',
  city: 'حلب',
  address_line: 'شارع النيل، بناء 4',
  is_rural: true,
};

// ── The shape checkout needs ────────────────────────────────────────────

dbTest('an address carries everything a delivery is priced by', async (world) => {
  const user = await makeUser(world.tx, 'a');
  const saved = await world.settings.createAddress(user.id, damascus);

  // Q53 prices by governorate and by city-centre versus rural; Q57 needs a
  // recipient. None of these existed on the old Western-shaped row.
  assert.equal(saved.governorate, 'دمشق');
  assert.equal(saved.district, 'المزة');
  assert.equal(saved.recipient_phone, '+963900111222');
  assert.equal(saved.landmark, 'قرب الصيدلية');
  assert.equal(saved.is_rural, false);
});

dbTest('the rural tier survives the round trip', async (world) => {
  const user = await makeUser(world.tx, 'b');
  const saved = await world.settings.createAddress(user.id, aleppo);
  assert.equal(saved.is_rural, true);
});

// ── Exactly one default ─────────────────────────────────────────────────

dbTest('her first address is the default whether she said so or not', async (world) => {
  const user = await makeUser(world.tx, 'c');
  const saved = await world.settings.createAddress(user.id, damascus);

  // Otherwise checkout opens with nothing selected on the one order she has
  // ever placed.
  assert.equal(saved.is_default, true);
});

dbTest('naming a new default demotes the old one', async (world) => {
  const user = await makeUser(world.tx, 'd');
  const home = await world.settings.createAddress(user.id, damascus);
  const work = await world.settings.createAddress(user.id, {
    ...aleppo,
    is_default: true,
  });

  const list = await world.settings.listAddresses(user.id);
  const defaults = list.filter((address) => address.is_default);
  assert.equal(defaults.length, 1);
  assert.equal(defaults[0].id, work.id);

  // …and the list leads with it, because that is the one checkout preselects.
  assert.equal(list[0].id, work.id);
  assert.equal(list.some((address) => address.id === home.id), true);
});

dbTest('deleting the default promotes another rather than leaving none', async (world) => {
  const user = await makeUser(world.tx, 'e');
  const home = await world.settings.createAddress(user.id, damascus);
  await world.settings.createAddress(user.id, aleppo);

  await world.settings.deleteAddress(user.id, home.id);

  const list = await world.settings.listAddresses(user.id);
  assert.equal(list.length, 1);
  assert.equal(list[0].is_default, true);
});

dbTest('setting a default is idempotent', async (world) => {
  const user = await makeUser(world.tx, 'f');
  const home = await world.settings.createAddress(user.id, damascus);

  await world.settings.setDefaultAddress(user.id, home.id);
  await world.settings.setDefaultAddress(user.id, home.id);

  const list = await world.settings.listAddresses(user.id);
  assert.equal(list.filter((address) => address.is_default).length, 1);
});

// ── Hers alone ──────────────────────────────────────────────────────────

dbTest("a woman cannot read, edit or delete another's address", async (world) => {
  const owner = await makeUser(world.tx, 'g');
  const stranger = await makeUser(world.tx, 'h');
  const saved = await world.settings.createAddress(owner.id, damascus);

  await assert.rejects(
    () => world.settings.updateAddress(stranger.id, saved.id, { city: 'حمص' }),
    /Address not found/,
  );
  await assert.rejects(
    () => world.settings.deleteAddress(stranger.id, saved.id),
    /Address not found/,
  );
  await assert.rejects(
    () => world.settings.setDefaultAddress(stranger.id, saved.id),
    /Address not found/,
  );

  const theirs = await world.settings.listAddresses(stranger.id);
  assert.equal(theirs.length, 0);
});

dbTest('an edit changes only what she sent', async (world) => {
  const user = await makeUser(world.tx, 'i');
  const saved = await world.settings.createAddress(user.id, damascus);

  const updated = await world.settings.updateAddress(user.id, saved.id, {
    landmark: 'مقابل المدرسة',
  });

  assert.equal(updated.landmark, 'مقابل المدرسة');
  assert.equal(updated.address_line, damascus.address_line);
  assert.equal(updated.recipient_phone, damascus.recipient_phone);
  assert.equal(updated.district, 'المزة');
});
