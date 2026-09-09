import assert from 'node:assert/strict';
import test from 'node:test';
import { PrismaClient, SupportTicketStatus, UserRole } from '@prisma/client';

import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { SupportService } from './support.service';

/**
 * Support conversations, which the platform could triage but nobody could
 * start.
 *
 * What is worth pinning is not that a row appears. It is that one woman never
 * sees another's conversation, that an internal note stays internal, and that
 * the queue can tell who is waiting on whom — because those are the three
 * things a support tool is actually for.
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
            await body({ tx, support: build(tx) });
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
  support: SupportService;
}

function build(tx: Tx): SupportService {
  const db = new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: (inner: Tx) => unknown) => fn(tx);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
  return new SupportService(db);
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;

async function makeUser(
  tx: Tx,
  tag: string,
  role: UserRole = UserRole.CUSTOMER,
): Promise<AuthUser> {
  const u = uniq(tag);
  const user = await tx.user.create({
    data: {
      name: `sup-${tag}`,
      username: `sup_${u}`,
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role,
    },
  });
  return { id: user.id, phone: user.phone, role };
}

const ticket = {
  subject: 'طلبي لم يصل',
  body: 'مرّ أسبوع ولم يصلني شيء',
};

// ── There is a way in ───────────────────────────────────────────────────

dbTest('a customer can open a conversation, with her first message in it', async (world) => {
  const customer = await makeUser(world.tx, 'a');
  const opened = await world.support.open(customer, ticket);

  assert.equal(opened.subject, ticket.subject);
  assert.equal(opened.status, SupportTicketStatus.OPEN);
  // A subject with no body is a subject line somebody has to chase.
  assert.equal(opened.messages.length, 1);
  assert.equal(opened.messages[0].body, ticket.body);
  assert.equal(opened.messages[0].from_support, false);
});

dbTest('tapping twice lands her back in the thread she started', async (world) => {
  const customer = await makeUser(world.tx, 'b');
  const first = await world.support.open(customer, ticket);
  const second = await world.support.open(customer, {
    ...ticket,
    body: 'هل من جديد؟',
  });

  // Splitting one problem across two queues makes each half look unanswered.
  assert.equal(second.id, first.id);
  assert.equal(second.messages.length, 2);

  const mine = await world.support.listMine(customer.id);
  assert.equal(mine.length, 1);
});

// ── Who is waiting on whom ──────────────────────────────────────────────

dbTest('the status says whose turn it is', async (world) => {
  const customer = await makeUser(world.tx, 'c');
  const agent = await makeUser(world.tx, 'd', UserRole.SUPPORT);
  const opened = await world.support.open(customer, ticket);

  await world.support.reply(opened.id, agent, { body: 'نتحقق من الشحنة' });
  const afterAgent = await world.support.detail(opened.id, agent);
  assert.equal(afterAgent.status, SupportTicketStatus.PENDING);

  await world.support.reply(opened.id, customer, { body: 'شكراً لكِ' });
  const afterCustomer = await world.support.detail(opened.id, customer);
  assert.equal(afterCustomer.status, SupportTicketStatus.OPEN);
});

dbTest('an internal note moves nothing and is seen by nobody outside', async (world) => {
  const customer = await makeUser(world.tx, 'e');
  const agent = await makeUser(world.tx, 'f', UserRole.SUPPORT);
  const opened = await world.support.open(customer, ticket);

  await world.support.reply(opened.id, agent, {
    body: 'الشحنة ضاعت — نعوّضها',
    internal: true,
  });

  const hers = await world.support.detail(opened.id, customer);
  assert.equal(hers.messages.length, 1, 'she sees only her own message');
  // Filtered out rather than marked hidden: a message she can see the
  // existence of is a message she will ask about.
  assert.equal(
    hers.messages.some((message) => message.internal),
    false,
  );
  assert.equal(
    hers.status,
    SupportTicketStatus.OPEN,
    'a note is not an answer',
  );

  const theirs = await world.support.detail(opened.id, agent);
  assert.equal(theirs.messages.length, 2);
});

dbTest('a customer cannot leave an internal note', async (world) => {
  const customer = await makeUser(world.tx, 'g');
  const opened = await world.support.open(customer, ticket);

  await assert.rejects(
    () =>
      world.support.reply(opened.id, customer, {
        body: 'ملاحظة',
        internal: true,
      }),
    /Only support/,
  );
});

// ── Hers alone ──────────────────────────────────────────────────────────

dbTest("a stranger cannot read another woman's conversation", async (world) => {
  const customer = await makeUser(world.tx, 'h');
  const stranger = await makeUser(world.tx, 'i');
  const opened = await world.support.open(customer, ticket);

  // Not a 403: confirming the id exists tells whoever guessed it that somebody
  // had a problem.
  await assert.rejects(
    () => world.support.detail(opened.id, stranger),
    /Ticket not found/,
  );
  await assert.rejects(
    () => world.support.reply(opened.id, stranger, { body: 'مرحباً' }),
    /Ticket not found/,
  );

  assert.equal((await world.support.listMine(stranger.id)).length, 0);
});

dbTest('a closed conversation takes no more messages', async (world) => {
  const customer = await makeUser(world.tx, 'j');
  const opened = await world.support.open(customer, ticket);

  await world.support.close(opened.id, customer);

  await assert.rejects(
    () => world.support.reply(opened.id, customer, { body: 'مرة أخرى' }),
    /closed/,
  );
});
