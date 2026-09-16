import assert from 'node:assert/strict';
import test from 'node:test';
import {
  PolicyAudience,
  PolicyDocumentKind,
  PolicyVersionStatus,
  PrismaClient,
  UserRole,
} from '@prisma/client';

import { HttpException } from '@nestjs/common';

import { PrismaService } from '../../prisma/prisma.service';
import {
  PoliciesService,
  PolicyConsentSource,
  consentAudiencesFor,
} from './policies.service';
import {
  PolicyAdminService,
  policyContentHash,
} from './policy-admin.service';

/**
 * The policy centre, and the four things that make a consent worth anything.
 *
 *  1. **A published version is frozen.** If the text can be edited under a
 *     signature, the signature records nothing.
 *  2. **Publishing leaves exactly one current version.** Two, or none, and
 *     every reader of "the terms" is reading something different.
 *  3. **Re-consent is a decision, not a side effect.** A new version only
 *     interrupts people when whoever published it said the change was
 *     material — otherwise a typo fix trains a hundred thousand women to tap
 *     through a consent screen without reading it.
 *  4. **Nobody signs the other side's contract.** A seller is not asked for
 *     the shopper's terms of use, and staff are not asked for anything.
 *
 * Everything here rolls back. The two unit tests at the top need no database
 * at all — the audience rule and the content hash are pure — so they run
 * everywhere, including on a developer machine pointed at Supabase where the
 * guard makes the integration half skip.
 */

// ── Pure ────────────────────────────────────────────────────────────────

test('a shopper and a seller sign different contracts', () => {
  const customer = consentAudiencesFor(UserRole.CUSTOMER);
  assert.deepEqual(customer.sort(), [
    PolicyAudience.CUSTOMER,
    PolicyAudience.EVERYONE,
  ]);
  assert.equal(customer.includes(PolicyAudience.SELLER), false);

  const seller = consentAudiencesFor(UserRole.SELLER);
  assert.deepEqual(seller.sort(), [
    PolicyAudience.EVERYONE,
    PolicyAudience.SELLER,
  ]);
  assert.equal(seller.includes(PolicyAudience.CUSTOMER), false);
});

test('staff are asked to sign nothing', () => {
  // A consent gate that blocks the admin console until somebody accepts the
  // shopper's terms of use is a self-inflicted outage the first time legal
  // publishes a version.
  for (const role of [
    UserRole.SUPER_ADMIN,
    UserRole.OPERATIONS_ADMIN,
    UserRole.SUPPORT,
    UserRole.FINANCE_ADMIN,
    UserRole.CONTENT_MODERATOR,
  ]) {
    assert.deepEqual(consentAudiencesFor(role), []);
  }
});

test('the content hash does not change with line endings', () => {
  // The same clause pasted from a Windows console and a Mac one is the same
  // clause; a hash that disagreed would raise a tamper flag on a paste.
  const body = '## عنوان\n\nفقرة أولى\n- بند\n';
  assert.equal(
    policyContentHash(body),
    policyContentHash(body.replace(/\n/g, '\r\n')),
  );
  assert.notEqual(policyContentHash(body), policyContentHash(`${body}.`));
});

// ── Integration ─────────────────────────────────────────────────────────

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

interface World {
  tx: Tx;
  policies: PoliciesService;
  admin: PolicyAdminService;
}

function build(tx: Tx): World {
  const db = new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: (inner: Tx) => unknown) => fn(tx);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;

  return {
    tx,
    policies: new PoliciesService(db),
    admin: new PolicyAdminService(db),
  };
}

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
            await body(build(tx));
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

/**
 * Matches a refusal by its machine code rather than its prose.
 *
 * These services throw `new ConflictException({ code, message })`, and Nest
 * does not copy an object response onto `error.message` — so a regex over the
 * message passes for any rejection at all, including the wrong one. Asserting
 * on the code is the difference between "it refused" and "it refused for the
 * reason this test is about".
 */
function refusalCoded(code: string) {
  return (error: unknown) => {
    assert.ok(error instanceof HttpException, `expected an HTTP refusal, got ${error}`);
    const body = error.getResponse() as { code?: string };
    assert.equal(body.code, code);
    return true;
  };
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;

async function makeUser(tx: Tx, tag: string, role: UserRole) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `pol-${tag}`,
      username: `pol_${u}`,
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role,
    },
  });
}

const BODY = '## الشروط\n\nنصّ كافٍ لتجاوز الحدّ الأدنى المفروض على النشر، مع بند أو بندين.';

/**
 * A published document, made for one test.
 *
 * `kind` is unique and `PolicyBootstrap` has already written all eight of
 * them, so a fixture cannot simply insert one — it first removes whatever
 * holds that kind. That would be alarming anywhere else; here every test body
 * runs inside a transaction this harness rolls back unconditionally, so the
 * delete never reaches committed data. It is the price of testing a table
 * whose primary key is a closed enum.
 */
async function makeDocument(
  tx: Tx,
  options: {
    kind: PolicyDocumentKind;
    audience?: PolicyAudience;
    requiredForConsent?: boolean;
  },
) {
  await tx.policyDocument.deleteMany({ where: { kind: options.kind } });

  const slug = uniq('slug').toLowerCase().replace(/[^a-z0-9]/g, '');
  const document = await tx.policyDocument.create({
    data: {
      kind: options.kind,
      slug,
      audience: options.audience ?? PolicyAudience.EVERYONE,
      requiredForConsent: options.requiredForConsent ?? true,
      versions: {
        create: {
          version: 1,
          status: PolicyVersionStatus.PUBLISHED,
          publishedAt: new Date(),
          effectiveAt: new Date(),
          translations: {
            create: {
              locale: 'ar',
              title: 'وثيقة',
              body: BODY,
              contentHash: policyContentHash(BODY),
            },
          },
        },
      },
    },
    include: { versions: true },
  });
  return { document, version: document.versions[0] };
}

// ── A published version is frozen ───────────────────────────────────────

dbTest('a published version refuses to be edited', async (world) => {
  const { version } = await makeDocument(world.tx, {
    kind: PolicyDocumentKind.CUSTOMER_TERMS,
  });

  await assert.rejects(
    () =>
      world.admin.updateVersion(version.id, {
        translations: [
          { locale: 'ar', title: 'مبدّل', body: `${BODY} إضافة` },
        ],
      }),
    refusalCoded('POLICY_VERSION_NOT_EDITABLE'),
  );

  // And the text she signed is still on disk, byte for byte.
  const translation = await world.tx.policyDocumentTranslation.findFirst({
    where: { versionId: version.id },
  });
  assert.equal(translation?.body, BODY);
});

dbTest('a second draft cannot be opened beside the first', async (world) => {
  const actor = await makeUser(world.tx, 'a', UserRole.SUPER_ADMIN);
  const { document } = await makeDocument(world.tx, {
    kind: PolicyDocumentKind.PRIVACY,
  });

  await world.admin.createVersion(document.id, {}, actor.id);
  await assert.rejects(
    () => world.admin.createVersion(document.id, {}, actor.id),
    refusalCoded('POLICY_DRAFT_EXISTS'),
  );
});

dbTest('a new draft is the published text, not a blank page', async (world) => {
  const actor = await makeUser(world.tx, 'b', UserRole.SUPER_ADMIN);
  const { document } = await makeDocument(world.tx, {
    kind: PolicyDocumentKind.RETURNS,
  });

  await world.admin.createVersion(document.id, {}, actor.id);

  const draft = await world.tx.policyDocumentVersion.findFirst({
    where: { documentId: document.id, status: PolicyVersionStatus.DRAFT },
    include: { translations: true },
  });
  // Amending one clause must not mean retyping the whole document, which is
  // where a clause goes missing.
  assert.equal(draft?.version, 2);
  assert.equal(draft?.translations[0].body, BODY);
});

// ── Exactly one current version ─────────────────────────────────────────

dbTest('publishing archives its predecessor', async (world) => {
  const actor = await makeUser(world.tx, 'c', UserRole.SUPER_ADMIN);
  const { document, version: first } = await makeDocument(world.tx, {
    kind: PolicyDocumentKind.CONTENT,
  });

  await world.admin.createVersion(document.id, {}, actor.id);
  const draft = await world.tx.policyDocumentVersion.findFirstOrThrow({
    where: { documentId: document.id, status: PolicyVersionStatus.DRAFT },
  });
  await world.admin.publishVersion(
    draft.id,
    { requires_reacceptance: false },
    actor.id,
  );

  const versions = await world.tx.policyDocumentVersion.findMany({
    where: { documentId: document.id },
  });
  const published = versions.filter(
    (row) => row.status === PolicyVersionStatus.PUBLISHED,
  );
  assert.equal(published.length, 1);
  assert.equal(published[0].id, draft.id);
  assert.equal(
    versions.find((row) => row.id === first.id)?.status,
    PolicyVersionStatus.ARCHIVED,
  );
});

// ── Re-consent is a decision ────────────────────────────────────────────

dbTest('an unsigned required policy is outstanding', async (world) => {
  const customer = await makeUser(world.tx, 'd', UserRole.CUSTOMER);
  const { document } = await makeDocument(world.tx, {
    kind: PolicyDocumentKind.LIABILITY,
    audience: PolicyAudience.EVERYONE,
    requiredForConsent: true,
  });

  const pending = await world.policies.pending(
    customer.id,
    UserRole.CUSTOMER,
    'ar',
  );
  assert.ok(pending.some((row) => row.id === document.id));
});

dbTest('signing it clears it, and signing twice writes once', async (world) => {
  const customer = await makeUser(world.tx, 'e', UserRole.CUSTOMER);
  const { document, version } = await makeDocument(world.tx, {
    kind: PolicyDocumentKind.DISPUTES,
  });

  const first = await world.policies.record(
    customer.id,
    [version.id],
    PolicyConsentSource.Registration,
    { locale: 'ar', ipAddress: '10.0.0.1' },
  );
  const second = await world.policies.record(
    customer.id,
    [version.id],
    PolicyConsentSource.Reconsent,
    { locale: 'ar' },
  );

  assert.equal(first, 1);
  // She tapped twice on a flaky connection. She signed once.
  assert.equal(second, 0);

  const pending = await world.policies.pending(
    customer.id,
    UserRole.CUSTOMER,
    'ar',
  );
  assert.equal(
    pending.some((row) => row.id === document.id),
    false,
  );

  // The record carries the text, not just the fact.
  const acceptance = await world.tx.policyAcceptance.findFirstOrThrow({
    where: { userId: customer.id, versionId: version.id },
  });
  assert.equal(acceptance.contentHash, policyContentHash(BODY));
  assert.equal(acceptance.source, PolicyConsentSource.Registration);
});

dbTest('a typo fix does not interrupt anyone', async (world) => {
  const actor = await makeUser(world.tx, 'f', UserRole.SUPER_ADMIN);
  const customer = await makeUser(world.tx, 'g', UserRole.CUSTOMER);
  const { document, version } = await makeDocument(world.tx, {
    kind: PolicyDocumentKind.COMMISSIONS,
    audience: PolicyAudience.EVERYONE,
  });

  await world.policies.record(
    customer.id,
    [version.id],
    PolicyConsentSource.Registration,
  );

  await world.admin.createVersion(document.id, {}, actor.id);
  const draft = await world.tx.policyDocumentVersion.findFirstOrThrow({
    where: { documentId: document.id, status: PolicyVersionStatus.DRAFT },
  });
  await world.admin.publishVersion(
    draft.id,
    { requires_reacceptance: false },
    actor.id,
  );

  const pending = await world.policies.pending(
    customer.id,
    UserRole.CUSTOMER,
    'ar',
  );
  assert.equal(
    pending.some((row) => row.id === document.id),
    false,
  );
});

dbTest('a material change asks her again', async (world) => {
  const actor = await makeUser(world.tx, 'h', UserRole.SUPER_ADMIN);
  const customer = await makeUser(world.tx, 'i', UserRole.CUSTOMER);
  const { document, version } = await makeDocument(world.tx, {
    kind: PolicyDocumentKind.SELLER_TERMS,
    audience: PolicyAudience.EVERYONE,
  });

  await world.policies.record(
    customer.id,
    [version.id],
    PolicyConsentSource.Registration,
  );

  await world.admin.createVersion(document.id, {}, actor.id);
  const draft = await world.tx.policyDocumentVersion.findFirstOrThrow({
    where: { documentId: document.id, status: PolicyVersionStatus.DRAFT },
  });
  await world.admin.publishVersion(
    draft.id,
    { requires_reacceptance: true },
    actor.id,
  );

  const pending = await world.policies.pending(
    customer.id,
    UserRole.CUSTOMER,
    'ar',
  );
  assert.ok(pending.some((row) => row.id === document.id));

  // Her old signature is not erased by the new demand — it is still the
  // record of what she agreed to in the first place.
  const receipts = await world.policies.acceptances(customer.id, 'ar');
  assert.ok(receipts.some((row) => row.version_id === version.id));
});

// ── Nobody signs the other side's contract ──────────────────────────────

dbTest('a seller is not asked for the shopper terms', async (world) => {
  const seller = await makeUser(world.tx, 'j', UserRole.SELLER);
  const { document } = await makeDocument(world.tx, {
    kind: PolicyDocumentKind.CUSTOMER_TERMS,
    audience: PolicyAudience.CUSTOMER,
  });

  const pending = await world.policies.pending(
    seller.id,
    UserRole.SELLER,
    'ar',
  );
  assert.equal(
    pending.some((row) => row.id === document.id),
    false,
  );

  // But she can still read it: publishing is not the same as demanding.
  const catalogue = await world.policies.catalogue('ar', seller.id);
  assert.ok(catalogue.some((row) => row.id === document.id));
});

dbTest('an app build that predates the feature can still register', async (world) => {
  // The API deploys before a new app reaches every handset, so for a few days
  // `POST /auth/register` is called by builds that have never heard of
  // `accepted_policy_version_ids`. Refusing those would mean nobody on the
  // shipped build could create an account until she updated.
  //
  // This pins the *distinction*, which is the part that is easy to lose:
  // an absent field is "did not know the question exists" and is allowed
  // through unsigned; an empty array is "was asked and covered nothing" and
  // is refused. `requiredVersionIds` is what both answers are measured
  // against, so this asserts on it and on the arithmetic above it.
  const { document } = await makeDocument(world.tx, {
    kind: PolicyDocumentKind.CUSTOMER_TERMS,
    audience: PolicyAudience.CUSTOMER,
    requiredForConsent: true,
  });

  // The whole required set, not just this fixture's document: a shopper also
  // signs privacy, and an earlier draft of this test supplied one id and
  // called the resulting refusal a bug in the code. Measuring against what
  // `requiredVersionIds` actually answers is the point of the helper.
  const required = await world.policies.requiredVersionIds(
    UserRole.CUSTOMER,
    world.tx,
  );
  assert.ok(required.some((row) => row.documentId === document.id));
  assert.ok(required.length >= 1);
  const everyId = required.map((row) => row.versionId);

  // Absent → nothing to record, and no refusal.
  assert.deepEqual(consentFor(required, undefined), []);
  // Present but empty → the caller was asked and answered nothing.
  assert.equal(consentFor(required, []), 'refused');
  // Present and complete → recorded.
  assert.deepEqual(consentFor(required, everyId), everyId);
  // Present but short of the full set → still refused.
  if (required.length > 1) {
    assert.equal(consentFor(required, [everyId[0]]), 'refused');
  }

  // And an account created without a signature is outstanding, not silently
  // treated as consenting — which is what makes the leniency above safe.
  const customer = await makeUser(world.tx, 'k', UserRole.CUSTOMER);
  const pending = await world.policies.pending(
    customer.id,
    UserRole.CUSTOMER,
    'ar',
  );
  assert.ok(pending.some((row) => row.id === document.id));
});

/**
 * The arithmetic `AuthService.requiredPolicyConsent` performs, mirrored.
 *
 * The service itself needs eleven collaborators to construct, so this pins the
 * rule rather than the wiring; the wiring is one `??` away from regressing and
 * the rule is what a reviewer needs to be able to read.
 */
function consentFor(
  required: { versionId: string }[],
  provided: string[] | undefined,
): string[] | 'refused' {
  if (provided === undefined) return [];
  if (required.length === 0) return [];
  const supplied = new Set(provided);
  const missing = required.filter((item) => !supplied.has(item.versionId));
  if (missing.length > 0) return 'refused';
  return required.map((item) => item.versionId);
}

dbTest('registration is told which documents are missing', async (world) => {
  const { document, version } = await makeDocument(world.tx, {
    kind: PolicyDocumentKind.PRIVACY,
    audience: PolicyAudience.EVERYONE,
    requiredForConsent: true,
  });

  const required = await world.policies.requiredVersionIds(
    UserRole.CUSTOMER,
    world.tx,
  );
  const entry = required.find((row) => row.documentId === document.id);
  assert.ok(entry, 'a required document must be named to the signup form');
  assert.equal(entry.versionId, version.id);
  assert.equal(entry.slug, document.slug);
});
