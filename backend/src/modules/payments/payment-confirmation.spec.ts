import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import { ForbiddenException } from '@nestjs/common';
import {
  Currency,
  Payment,
  PaymentMethodType,
  PaymentStatus,
} from '@prisma/client';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { PaymentsService } from './payments.service';
import { PaymentProviderRegistry } from './providers/payment-provider.registry';
import {
  BankCardProvider,
  BankTransferProvider,
  CodProvider,
  CourierCollectProvider,
  HawalaProvider,
  MtnCashProvider,
  PlatformWalletProvider,
  ShamCashProvider,
  SyriatelCashProvider,
} from './providers/payment.providers';

/** Every rail the platform actually offers, wired the way the module wires it. */
const allProviders = () => [
  new CodProvider(),
  new CourierCollectProvider(),
  new SyriatelCashProvider(),
  new MtnCashProvider(),
  new ShamCashProvider(),
  new BankCardProvider(),
  new BankTransferProvider(),
  new HawalaProvider(),
  new PlatformWalletProvider(),
];

/**
 * `POST /payments/:id/verify` is reachable by the customer who owns the
 * payment, and every provider here is a stub whose `verify` answers PAID
 * without asking anyone. Together that was a way to buy for free: confirm your
 * own payment, the ledger takes a `PLATFORM_CASH` debit, `checkout.confirm`
 * fans the sub-orders out, and the sellers ship.
 *
 * These cases hold the two halves of the fix in place — that no provider
 * claims an attestation it cannot make, and that the endpoint refuses when
 * none can.
 */

const PENDING_COD = {
  id: 'pay-1',
  orderId: 'order-1',
  method: PaymentMethodType.COD,
  status: PaymentStatus.PENDING,
  currency: Currency.SYP,
  amount: new Prisma.Decimal(1000),
  capturedAmount: new Prisma.Decimal(0),
  transactionRef: 'COD-ABC',
  providerRef: null,
} as unknown as Payment;

/** Enough of the service's collaborators to reach the guard and no further. */
function serviceWith(sandbox: boolean): PaymentsService {
  const prisma = {
    payment: { findFirst: async () => PENDING_COD },
    $transaction: async () => {
      throw new Error('settlement must not be reached');
    },
  } as unknown as PrismaService;

  const registry = new PaymentProviderRegistry(allProviders());
  const config = new ConfigService({
    payments: { sandboxConfirmation: sandbox },
  });

  return new PaymentsService(
    prisma,
    registry,
    { emit: () => true } as never,
    { confirm: async () => undefined } as never,
    {} as never,
    {} as never,
    config,
  );
}

test('a customer cannot confirm her own payment on a rail nobody can attest', async () => {
  await assert.rejects(
    () => serviceWith(false).verify('user-1', 'pay-1'),
    (error: unknown) => {
      assert.ok(error instanceof ForbiddenException);
      assert.match(String(error.message), /PAYMENT_CONFIRMATION_UNAVAILABLE/);
      return true;
    },
  );
});

test('the sandbox switch is what makes local development still work', async () => {
  // Reaching settlement is the proof the guard was the only thing in the way;
  // the stub transaction throws on purpose so nothing is actually written.
  await assert.rejects(
    () => serviceWith(true).verify('user-1', 'pay-1'),
    /settlement must not be reached/,
  );
});

test('no provider claims it can attest settlement', () => {
  const registry = new PaymentProviderRegistry(allProviders());

  const attesting = allProviders()
    .filter((provider) => provider.attestsSettlement)
    .map((provider) => provider.method);

  assert.deepEqual(
    attesting,
    [],
    'a provider claims it can prove money moved — its verify must authenticate the gateway first',
  );
  // And the registry really does cover every rail the catalogue offers.
  assert.equal(registry.list().length, allProviders().length);
});
