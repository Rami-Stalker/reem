/**
 * Records the loyalty expense an older seed forgot to write.
 *
 *   npx ts-node -r tsconfig-paths/register scripts/repair-loyalty-accrual.ts
 *
 * Points were minted straight into `points_transactions` without the entry
 * that puts the promise on the balance sheet. Nothing looked wrong until a
 * shopper converted points into wallet credit in the app: that debits
 * `LOYALTY_LIABILITY`, and a liability nobody had ever credited went negative
 * — so the finance console reported the books unsound, and it was right.
 *
 * `demo/commerce.ts` accrues as it mints now, so a fresh dataset never has the
 * gap. This is for a database that already carries it.
 *
 * **What it accrues, and what it deliberately does not.** It recognises only
 * what the platform has actually handed over — the credit already drawn out of
 * the liability — because that expense certainly happened. It does *not*
 * accrue the credit that outstanding point balances could still be converted
 * into: this dataset carries balances in the millions of points, residue of
 * the checkout bug that once minted a point per pound rather than per 100, and
 * accruing those would put a fiction on the balance sheet far larger than the
 * one being fixed. What to do about those balances — honour them or write them
 * down — is a business decision, not a repair script's.
 *
 * Safe to re-run: it does nothing when the account is not negative, and its
 * reference is stable so a second pass cannot double-count.
 */
import {
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  PrismaClient,
} from '@prisma/client';

import { Money } from '../src/common/money';
import { LedgerService } from '../src/modules/ledger/ledger.service';
import { PrismaService } from '../src/prisma/prisma.service';

/**
 * References are unique on `journal_entries` — posting the same one twice
 * returns the original rather than duplicating it — so a repair that was
 * reversed needs a fresh one. The suffix counts attempts; the guard below
 * refuses to post at all unless the account is actually short.
 */
const REFERENCE = 'repair:loyalty-accrual:v2';

async function main(): Promise<void> {
  const prisma = new PrismaClient();
  const ledger = new LedgerService(prisma as unknown as PrismaService);

  const account = await prisma.ledgerAccount.findFirst({
    where: {
      code: LedgerAccountCode.LOYALTY_LIABILITY,
      currency: Currency.SYP,
    },
  });
  const balance = account ? Number(account.balance) : 0;
  console.log(`loyalty liability: ${balance} SYP`);

  if (balance >= 0) {
    console.log('Nothing drawn against an unrecorded promise — leaving it.');
    await prisma.$disconnect();
    return;
  }

  const existing = await prisma.journalEntry.findFirst({
    where: { reference: REFERENCE, reversedBy: null },
  });
  if (existing) {
    console.log('This repair has already been posted; leaving it alone.');
    await prisma.$disconnect();
    return;
  }

  const amount = Money.of(Math.abs(balance), Currency.SYP);
  await ledger.post({
    type: JournalEntryType.LOYALTY_ACCRUED,
    reference: REFERENCE,
    description: 'استدراك مصروف نقاط الولاء المصروفة فعلياً',
    lines: [
      {
        account: { code: LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE },
        direction: LedgerDirection.DEBIT,
        amount,
      },
      {
        account: { code: LedgerAccountCode.LOYALTY_LIABILITY },
        direction: LedgerDirection.CREDIT,
        amount,
      },
    ],
  });

  console.log(`Accrued ${amount.toJSON().amount} SYP; the liability is level.`);
  await prisma.$disconnect();
}

void main();
