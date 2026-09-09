import assert from 'node:assert/strict';
import test from 'node:test';
import { createHmac } from 'node:crypto';
import {
  DeliveryProviderAccount,
  DeliveryProviderKind,
  ShipmentStatus,
  WebhookAuthScheme,
} from '@prisma/client';

import { HttpDeliveryProvider } from './http-delivery.provider';
import { ProviderCredentialsService } from './provider-credentials.service';

/**
 * The generic carrier adapter, at the two points where being wrong is
 * expensive: the signature that guards a public endpoint capable of marking
 * parcels delivered, and the parsing that decides what a carrier said.
 */

const SECRET = 'carrier-signing-secret';

function credentials(): ProviderCredentialsService {
  return {
    resolve: () => ({ webhookSecret: SECRET, extra: {} }),
  } as unknown as ProviderCredentialsService;
}

function account(
  overrides: Partial<DeliveryProviderAccount> = {},
): DeliveryProviderAccount {
  return {
    id: 'account-1',
    code: 'http_generic',
    displayName: 'Acme',
    kind: DeliveryProviderKind.EXTERNAL_API,
    isEnabled: true,
    isDefault: true,
    priority: 10,
    governorates: [],
    supportsQuote: false,
    supportsCancel: true,
    supportsTracking: true,
    supportsWebhook: true,
    webhookAuth: WebhookAuthScheme.HMAC_SHA256,
    webhookSignatureHeader: 'x-acme-signature',
    config: {},
    credentialEnvKeys: {},
    courierId: null,
    lastHealthyAt: null,
    lastErrorAt: null,
    lastError: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  } as DeliveryProviderAccount;
}

function signed(body: unknown, secret = SECRET) {
  const raw = Buffer.from(JSON.stringify(body));
  return {
    rawBody: raw,
    headers: {
      'x-acme-signature': createHmac('sha256', secret).update(raw).digest('hex'),
    },
    body,
  };
}

test('a correctly signed callback is accepted and parsed', async () => {
  const provider = new HttpDeliveryProvider(credentials());
  const verdict = await provider.handleWebhook(
    account(),
    signed({
      event_id: 'evt-1',
      delivery_id: 'ACME-99',
      status: 'out_for_delivery',
      timestamp: '2026-09-09T08:00:00.000Z',
    }),
  );

  assert.equal(verdict.signatureValid, true);
  assert.equal(verdict.events.length, 1);
  assert.equal(verdict.events[0].externalDeliveryId, 'ACME-99');
  assert.equal(verdict.events[0].status, ShipmentStatus.OUT_FOR_DELIVERY);
  assert.equal(verdict.events[0].externalEventId, 'evt-1');
});

test('a callback signed with the wrong secret is refused', async () => {
  const provider = new HttpDeliveryProvider(credentials());
  const verdict = await provider.handleWebhook(
    account(),
    signed({ delivery_id: 'ACME-99', status: 'delivered' }, 'not-the-secret'),
  );

  // Parsed — so the event log can show what arrived — but never trusted.
  assert.equal(verdict.signatureValid, false);
});

test('a callback with no signature at all is refused', async () => {
  const provider = new HttpDeliveryProvider(credentials());
  const body = { delivery_id: 'ACME-99', status: 'delivered' };
  const verdict = await provider.handleWebhook(account(), {
    rawBody: Buffer.from(JSON.stringify(body)),
    headers: {},
    body,
  });

  assert.equal(verdict.signatureValid, false);
});

test('unsigned callbacks are refused unless the account opts in', async () => {
  const provider = new HttpDeliveryProvider(credentials());
  const body = { delivery_id: 'ACME-1', status: 'delivered' };
  const request = { rawBody: Buffer.from(JSON.stringify(body)), headers: {}, body };

  const strict = await provider.handleWebhook(
    account({ webhookAuth: WebhookAuthScheme.NONE }),
    request,
  );
  assert.equal(strict.signatureValid, false, 'NONE alone is not permission');

  const sandbox = await provider.handleWebhook(
    account({
      webhookAuth: WebhookAuthScheme.NONE,
      config: { allowUnsignedWebhooks: true } as never,
    }),
    request,
  );
  assert.equal(sandbox.signatureValid, true, 'an explicit opt-in is');
});

test('a batch of events is parsed as a batch', async () => {
  const provider = new HttpDeliveryProvider(credentials());
  const verdict = await provider.handleWebhook(
    account(),
    signed({
      events: [
        { event_id: 'a', delivery_id: 'D1', status: 'picked_up' },
        { event_id: 'b', delivery_id: 'D2', status: 'delivered' },
      ],
    }),
  );

  assert.equal(verdict.events.length, 2);
  assert.equal(verdict.events[1].status, ShipmentStatus.DELIVERED);
});

test("an event about a status we do not understand is dropped, not guessed", async () => {
  const provider = new HttpDeliveryProvider(credentials());
  const verdict = await provider.handleWebhook(
    account(),
    signed({ delivery_id: 'D1', status: 'left_at_the_bakery' }),
  );

  assert.equal(verdict.signatureValid, true);
  assert.equal(verdict.events.length, 0);
});

test("a carrier's own status words are honoured", async () => {
  const provider = new HttpDeliveryProvider(credentials());
  const verdict = await provider.handleWebhook(
    account({ config: { statusMap: { '3': 'DELIVERED' } } as never }),
    signed({ delivery_id: 'D1', status: '3' }),
  );

  assert.equal(verdict.events[0]?.status, ShipmentStatus.DELIVERED);
});

test('a shared-secret carrier is compared against the header, not the body', async () => {
  const provider = new HttpDeliveryProvider(credentials());
  const body = { delivery_id: 'D1', status: 'delivered' };

  const right = await provider.handleWebhook(
    account({ webhookAuth: WebhookAuthScheme.SHARED_SECRET }),
    { rawBody: Buffer.from('{}'), headers: { 'x-acme-signature': SECRET }, body },
  );
  assert.equal(right.signatureValid, true);

  const wrong = await provider.handleWebhook(
    account({ webhookAuth: WebhookAuthScheme.SHARED_SECRET }),
    { rawBody: Buffer.from('{}'), headers: { 'x-acme-signature': 'guess' }, body },
  );
  assert.equal(wrong.signatureValid, false);
});
