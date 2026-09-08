/**
 * Re-derives cached ledger balances from the lines they summarise.
 *
 *   npx ts-node -r tsconfig-paths/register scripts/repair-account-balances.ts [--apply]
 *
 * `LedgerAccount.balance` is a cache. The truth is `journal_lines`, and
 * `LedgerService.post` is the only thing that may move the two together — that
 * is the invariant `verifyAccount` and the nightly reconciliation exist to
 * check, and a disagreement is a bug report, not routine drift. So this script
 * reports by default and only writes when told to.
 *
 * **Why a repair for this is not a posted entry.** Every other repair in this
 * directory works the way accounting should: it posts a new balanced entry and
 * lets the ledger move itself. That cannot fix *this* fault. Posting adds X to
 * the cache and X to the lines, so a gap between them survives untouched, and
 * a correcting entry sized to close it on one side only widens it on the
 * other. The lines are the record; when the cache disagrees with them the
 * cache is what is wrong, and re-deriving it is the only repair that does not
 * invent a transaction nobody made.
 *
 * **The fault it was written for.** A concurrency test committed a real points
 * conversion and then tidied up by deleting the journal entry it had created.
 * That removed the customer's half of a balanced pair and left the platform's
 * LOYALTY_LIABILITY cache still carrying the debit — 300 SYP light against its
 * own lines. `a healthy book reports sound` caught it the same day. The test
 * no longer deletes anything from the ledger (see the note at the top of
 * `oversell.concurrency.spec.ts`), and nothing in the application deletes a
 * posted entry, so this should have nothing to do on a healthy database.
 *
 * It never invents a figure: the number it writes is the sum of the account's
 * own lines under that account's normal direction. Safe to re-run.
 */
import { LedgerDirection, PrismaClient } from '@prisma/client';

import { isDebitNormal } from '../src/modules/ledger/chart-of-accounts';

interface Drift {
  id: string;
  label: string;
  cached: number;
  derived: number;
}

async function main(): Promise<void> {
  const apply = process.argv.includes('--apply');
  const prisma = new PrismaClient();

  const accounts = await prisma.ledgerAccount.findMany({
    select: {
      id: true,
      code: true,
      kind: true,
      currency: true,
      balance: true,
      ownerId: true,
    },
  });

  const drifted: Drift[] = [];

  for (const account of accounts) {
    const sums = await prisma.journalLine.groupBy({
      by: ['direction'],
      where: { accountId: account.id },
      _sum: { amount: true },
    });
    const debit = Number(
      sums.find((s) => s.direction === LedgerDirection.DEBIT)?._sum.amount ?? 0,
    );
    const credit = Number(
      sums.find((s) => s.direction === LedgerDirection.CREDIT)?._sum.amount ?? 0,
    );
    // The one sign rule, taken from the chart of accounts rather than repeated
    // here — a second copy of it is how a repair script starts disagreeing
    // with the ledger it is repairing.
    const derived = isDebitNormal(account.kind) ? debit - credit : credit - debit;
    const cached = Number(account.balance);

    if (cached !== derived) {
      drifted.push({
        id: account.id,
        label: `${account.code} (${account.currency})${
          account.ownerId ? ` owner ${account.ownerId.slice(0, 8)}` : ''
        }`,
        cached,
        derived,
      });
    }
  }

  if (drifted.length === 0) {
    console.log(
      `${accounts.length} accounts checked; every cached balance agrees with its lines.`,
    );
    await prisma.$disconnect();
    return;
  }

  console.log(`${drifted.length} account(s) disagree with their own lines:\n`);
  for (const d of drifted) {
    const delta = d.derived - d.cached;
    console.log(
      `  ${d.label}\n    cached ${d.cached}  ·  derived ${d.derived}  ·  ${
        delta > 0 ? '+' : ''
      }${delta}`,
    );
  }

  if (!apply) {
    console.log(
      '\nReported only. Re-run with --apply to write the derived figures.',
    );
    await prisma.$disconnect();
    return;
  }

  for (const d of drifted) {
    await prisma.ledgerAccount.update({
      where: { id: d.id },
      data: { balance: d.derived },
    });
    console.log(`repaired ${d.label}: ${d.cached} -> ${d.derived}`);
  }

  console.log(`\n${drifted.length} account(s) re-derived from their lines.`);
  await prisma.$disconnect();
}

void main();
