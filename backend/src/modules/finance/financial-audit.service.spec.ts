import assert from 'node:assert/strict';
import test from 'node:test';
import { AuditSeverity, Currency } from '@prisma/client';

import { Money } from '../../common/money';
import { AuditService } from '../auth/audit.service';
import {
  FinancialAction,
  FinancialAuditService,
} from './financial-audit.service';

/**
 * Q65 does not just say *that* money actions are logged, it says what each
 * record has to contain: «من قام بالعملية، ماذا غيّر، القيمة قبل وبعد،
 * التاريخ والوقت، والسبب إن كانت العملية حساسة».
 *
 * These check the shape actually written, because a log missing the "before"
 * is only useful for proving something happened, not for proving what.
 */
interface Recorded {
  actorId?: string | null;
  action: string;
  category: string;
  outcome: string;
  severity?: AuditSeverity;
  metadata?: Record<string, unknown>;
}

function makeService(): { service: FinancialAuditService; written: Recorded[] } {
  const written: Recorded[] = [];
  const fake = {
    record: async (input: Recorded) => {
      written.push(input);
    },
  } as unknown as AuditService;
  return { service: new FinancialAuditService(fake), written };
}

const syp = (v: string) => Money.of(v, Currency.SYP);

test('a record carries actor, subject, before, after and reason', async () => {
  const { service, written } = makeService();

  await service.record({
    action: FinancialAction.WalletCredited,
    actorId: 'admin-1',
    subjectId: 'wallet-9',
    subjectType: 'wallet',
    before: syp('10000'),
    after: syp('35000'),
    reason: 'تعويض عن تأخر التسليم',
  });

  assert.equal(written.length, 1);
  const entry = written[0];

  assert.equal(entry.actorId, 'admin-1');
  assert.equal(entry.action, 'wallet.credited');
  assert.equal(entry.category, 'finance');
  assert.equal(entry.metadata?.subject_id, 'wallet-9');
  assert.equal(entry.metadata?.subject_type, 'wallet');
  assert.equal(entry.metadata?.reason, 'تعويض عن تأخر التسليم');

  // Amounts keep their currency: a bare number in a log read years later
  // cannot be interpreted.
  assert.deepEqual(entry.metadata?.before, {
    amount: '10000.0000',
    currency: Currency.SYP,
  });
  assert.deepEqual(entry.metadata?.after, {
    amount: '35000.0000',
    currency: Currency.SYP,
  });
});

test('a balance change records the delta alongside before and after', async () => {
  const { service, written } = makeService();

  await service.recordBalanceChange(FinancialAction.WalletCredited, {
    actorId: 'admin-1',
    subjectId: 'wallet-9',
    subjectType: 'wallet',
    before: syp('10000'),
    after: syp('35000'),
    reason: 'gift',
  });

  assert.deepEqual(written[0].metadata?.delta, {
    amount: '25000.0000',
    currency: Currency.SYP,
  });
});

test('a debit records a negative delta', async () => {
  const { service, written } = makeService();

  await service.recordBalanceChange(FinancialAction.WalletCredited, {
    subjectId: 'wallet-9',
    subjectType: 'wallet',
    before: syp('35000'),
    after: syp('5000'),
  });

  assert.deepEqual(written[0].metadata?.delta, {
    amount: '-30000.0000',
    currency: Currency.SYP,
  });
});

test('a missing before or after is stored as null, not omitted', async () => {
  const { service, written } = makeService();

  // A first credit has no "before"; a refused rate has no "after". Both must
  // still produce a record with the field present, so a reader can tell
  // "nothing was there" from "nobody wrote it down".
  await service.record({
    action: FinancialAction.ExchangeRatePublished,
    subjectId: 'USD/SYP',
    after: '15250',
  });

  assert.equal(written[0].metadata?.before, null);
  assert.equal(written[0].metadata?.after, '15250');
});

test('a refused action is recorded, and louder than a successful one', async () => {
  const { service, written } = makeService();

  // The case that matters most: someone tried to release money they were not
  // allowed to. A refusal that leaves no trace is indistinguishable from
  // never having been attempted.
  await service.record({
    action: FinancialAction.PayoutStatusChanged,
    actorId: 'accountant-2',
    subjectId: 'payout-3',
    outcome: 'refused',
    reason: 'Only the general manager may approve or release a payout',
  });

  assert.equal(written[0].outcome, 'refused');
  assert.equal(written[0].severity, AuditSeverity.WARNING);
  assert.equal(
    written[0].metadata?.reason,
    'Only the general manager may approve or release a payout',
  );
});

test('every named action is a finance-category record', async () => {
  const { service, written } = makeService();

  for (const action of Object.values(FinancialAction)) {
    await service.record({ action, subjectId: 'x' });
  }

  assert.equal(written.length, Object.values(FinancialAction).length);
  for (const entry of written) {
    assert.equal(
      entry.category,
      'finance',
      `${entry.action} must be filterable as finance`,
    );
  }
});

test('Q65 names every action the log has to cover', () => {
  // The list the client wrote, mapped to the constants. If someone removes one
  // of these, this fails rather than the omission being noticed in an audit.
  const required = [
    FinancialAction.PayoutStatusChanged, // «صرف أرباح»
    FinancialAction.WalletCredited, // «إضافة/خصم رصيد من المحافظ»
    FinancialAction.ExchangeRatePublished, // «تعديل سعر الصرف»
    FinancialAction.CommissionRuleChanged, // «تعديل العمولات أو الباقات»
  ];

  for (const action of required) {
    assert.ok(
      Object.values(FinancialAction).includes(action),
      `${action} is required by Q65`,
    );
  }
});
