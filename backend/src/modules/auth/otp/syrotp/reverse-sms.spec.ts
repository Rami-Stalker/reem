import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import { HttpException } from '@nestjs/common';
import { OtpPurpose, ReverseCeremony } from '@prisma/client';

import { ReverseSmsService, operatorHint } from './reverse-sms.service';
import { SyrotpClient } from './syrotp.client';

/**
 * The reverse rail's decisions, with the provider replaced by a scripted
 * `fetch`. What matters here is which ceremony is opened and what happens when
 * the provider says no — the HTTP plumbing is the easy part.
 */

type Reply = { status: number; body: unknown };

/** Replaces `fetch` with a scripted queue and records what was asked. */
function scripted(replies: Reply[]) {
  const calls: { method: string; url: string; body: unknown }[] = [];
  const original = globalThis.fetch;
  globalThis.fetch = (async (url: string | URL, init?: RequestInit) => {
    calls.push({
      method: init?.method ?? 'GET',
      url: String(url),
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    const next = replies.shift();
    if (!next) throw new Error('unscripted request');
    return {
      ok: next.status >= 200 && next.status < 300,
      status: next.status,
      json: async () => next.body,
    } as Response;
  }) as typeof fetch;
  return { calls, restore: () => (globalThis.fetch = original) };
}

function service(overrides: Record<string, unknown> = {}) {
  const config = new ConfigService({
    otpDelivery: {
      reverse: {
        enabled: true,
        primary: true,
        baseUrl: 'https://otp.test',
        secretKey: 'sk_live_spec',
        receiverId: 'rcv_spec',
        timeoutMs: 1_000,
        ...overrides,
      },
    },
  });
  return new ReverseSmsService(new SyrotpClient(config), config);
}

test('a bound number gets a verification to send', async () => {
  const net = scripted([
    {
      status: 201,
      body: {
        id: 'vrf_1',
        status: 'pending',
        send_to: '+963991111111',
        message: 'VERIFY 763PM5',
        expires_at: '2026-10-22T10:00:00.000Z',
      },
    },
  ]);
  try {
    const challenge = await service().start({
      phone: '+963944000111',
      purpose: OtpPurpose.LOGIN,
    });
    assert.deepEqual(
      {
        ceremony: challenge?.ceremony,
        ref: challenge?.ref,
        sendTo: challenge?.sendTo,
        smsBody: challenge?.smsBody,
      },
      {
        ceremony: ReverseCeremony.VERIFICATION,
        ref: 'vrf_1',
        sendTo: '+963991111111',
        smsBody: 'VERIFY 763PM5',
      },
    );
    // The purpose is namespaced and the operator hint is derived, so one
    // provider instance can serve more than this platform and still route.
    assert.equal(net.calls[0].url, 'https://otp.test/v1/verifications');
    // `client_ref` is absent rather than null: JSON.stringify drops an
    // undefined property, which is what we want on an optional field.
    assert.deepEqual(net.calls[0].body, {
      phone: '+963944000111',
      purpose: 'reem:login',
      operator: 'mtn',
    });
  } finally {
    net.restore();
  }
});

test('an unseen number is sent through the binding ceremony first', async () => {
  const net = scripted([
    { status: 403, body: { error: { code: 'phone_not_bound' } } },
    {
      status: 201,
      body: {
        binding_id: 'pbn_1',
        phone_e164: '+963991234567',
        receiver_id: 'rcv_spec',
        status: 'pending',
        expires_at: '2026-10-22T10:00:00.000Z',
        send_to: '+963991111111',
        bind_message: 'BIND ABCD1234',
      },
    },
  ]);
  try {
    const challenge = await service().start({
      phone: '+963991234567',
      purpose: OtpPurpose.PHONE_VERIFICATION,
    });
    assert.equal(challenge?.ceremony, ReverseCeremony.BINDING);
    assert.equal(challenge?.ref, 'pbn_1');
    assert.equal(challenge?.smsBody, 'BIND ABCD1234');
    assert.equal(net.calls[1].url, 'https://otp.test/v1/phone-bindings/start');
    assert.deepEqual(net.calls[1].body, {
      phone: '+963991234567',
      receiver_id: 'rcv_spec',
    });
  } finally {
    net.restore();
  }
});

test('an unreachable provider answers null, so the caller can fall back', async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (async () => {
    throw new Error('ECONNREFUSED');
  }) as typeof fetch;
  try {
    assert.equal(
      await service().start({
        phone: '+963944000111',
        purpose: OtpPurpose.LOGIN,
      }),
      null,
    );
  } finally {
    globalThis.fetch = original;
  }
});

test('a 5xx is an outage, not a refusal', async () => {
  const net = scripted([{ status: 503, body: { error: { code: 'unavailable' } } }]);
  try {
    assert.equal(
      await service().start({
        phone: '+963944000111',
        purpose: OtpPurpose.LOGIN,
      }),
      null,
    );
  } finally {
    net.restore();
  }
});

test("the provider's pending cap is not laundered by falling back", async () => {
  const net = scripted([
    { status: 409, body: { error: { code: 'too_many_pending' } } },
  ]);
  try {
    await assert.rejects(
      service().start({ phone: '+963944000111', purpose: OtpPurpose.LOGIN }),
      (error: unknown) => {
        assert.ok(error instanceof HttpException);
        assert.equal(error.getStatus(), 429);
        assert.equal(
          (error.getResponse() as { code: string }).code,
          'TOO_MANY_ATTEMPTS',
        );
        return true;
      },
    );
  } finally {
    net.restore();
  }
});

test('a start reply with no address to send to is unusable', async () => {
  const net = scripted([
    {
      status: 201,
      body: { id: 'vrf_2', status: 'pending', expires_at: '2026-10-22T10:00:00.000Z' },
    },
  ]);
  try {
    assert.equal(
      await service().start({
        phone: '+963944000111',
        purpose: OtpPurpose.LOGIN,
      }),
      null,
    );
  } finally {
    net.restore();
  }
});

test('an outage while polling leaves a ceremony pending, never torn down', async () => {
  const net = scripted([{ status: 502, body: {} }]);
  try {
    assert.equal(
      await service().status(ReverseCeremony.VERIFICATION, 'vrf_1'),
      'pending',
    );
  } finally {
    net.restore();
  }
});

test('expired, cancelled and failed all read as unusable', async () => {
  for (const status of ['expired', 'cancelled', 'failed']) {
    const net = scripted([
      { status: 200, body: { id: 'vrf_1', status, expires_at: 'x' } },
    ]);
    try {
      assert.equal(
        await service().status(ReverseCeremony.VERIFICATION, 'vrf_1'),
        'unusable',
      );
    } finally {
      net.restore();
    }
  }
});

test('a verified binding settles a binding ceremony', async () => {
  const net = scripted([
    { status: 200, body: { id: 'pbn_1', status: 'verified', expires_at: 'x' } },
  ]);
  try {
    assert.equal(
      await service().status(ReverseCeremony.BINDING, 'pbn_1'),
      'verified',
    );
    assert.equal(net.calls[0].url, 'https://otp.test/v1/phone-bindings/pbn_1');
  } finally {
    net.restore();
  }
});

test('an unconfigured or demoted rail is not primary', () => {
  assert.equal(service().isPrimary(), true);
  assert.equal(service({ primary: false }).isPrimary(), false);
  assert.equal(service({ primary: false }).isUsable(), true);
  assert.equal(service({ enabled: false }).isUsable(), false);
  assert.equal(service({ secretKey: undefined }).isUsable(), false);
  assert.equal(service({ receiverId: undefined }).isUsable(), false);
});

test('operator hints follow the Syrian mobile prefixes', () => {
  assert.equal(operatorHint('+963933000000'), 'syriatel');
  assert.equal(operatorHint('0988000000'), 'syriatel');
  assert.equal(operatorHint('+963944000111'), 'mtn');
  assert.equal(operatorHint('0956000000'), 'mtn');
  // A landline or a foreign number is left to the provider's own routing.
  assert.equal(operatorHint('+963112345678'), undefined);
  assert.equal(operatorHint('+905551234567'), undefined);
});
