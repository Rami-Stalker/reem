/**
 * The external-carrier journey, end to end, against a running API.
 *
 *   node scripts/delivery-e2e.mjs
 *
 * Stands up a sandbox "delivery company" on localhost, registers it through the
 * admin API, walks a real order to the point where the seller marks it packed,
 * and then plays the carrier: accepting the delivery, and calling Ohara's
 * webhook — signed — through picked_up → out_for_delivery → delivered.
 *
 * What it proves, which no unit test can:
 *
 *   * dispatch really reaches an outside HTTP service, with an idempotency key
 *     and the carrier's credential taken from the environment;
 *   * a signed callback moves the order, and an unsigned one does not;
 *   * a redelivered callback does nothing the second time;
 *   * the buyer's own tracking page names the carrier.
 *
 * It is a script rather than a spec because it needs the whole application
 * running — the routes, the guards, the raw-body signature check. Requires
 * `OTP_DEV_INBOX_ENABLED=true`, like the other manual-test tooling.
 */
import { createHmac, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const BASE = process.env.BASE ?? 'http://127.0.0.1:3001';
const CARRIER_PORT = Number(process.env.CARRIER_PORT ?? 9099);
const WEBHOOK_SECRET = process.env.ACME_WEBHOOK_SECRET ?? 'sandbox-webhook-secret';

const ADMIN = process.env.ADMIN_PHONE ?? '+963911111111';
const SELLER = process.env.SELLER_PHONE ?? '+963931000109';
const BUYER = process.env.BUYER_PHONE ?? '+963933333333';

const CODE = `acme_sandbox`;
const RUN = Date.now().toString(36).toUpperCase();

let failures = 0;
const step = async (name, fn) => {
  try {
    const note = await fn();
    console.log(`PASS ${name}${note ? ` — ${note}` : ''}`);
  } catch (error) {
    failures += 1;
    console.log(`FAIL ${name}\n     ${error.message}`);
  }
};

// ── HTTP helpers ────────────────────────────────────────────────────────

async function api(token, method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let parsed = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = text;
  }
  return { status: res.status, body: parsed };
}

function expect(res, codes, what) {
  const list = Array.isArray(codes) ? codes : [codes];
  if (!list.includes(res.status)) {
    throw new Error(
      `${what}: expected ${list.join('/')}, got ${res.status} — ${JSON.stringify(res.body).slice(0, 400)}`,
    );
  }
  return res.body;
}

/**
 * Sessions are cached between runs.
 *
 * Not a convenience: one-time codes are rate limited to five an hour per
 * number, which a script that signs three accounts in on every run exhausts in
 * two runs. The cache holds refresh tokens, which is what a real client does.
 */
const TOKEN_CACHE = join(tmpdir(), 'reem-delivery-e2e-tokens.json');
const loadTokens = () => {
  try {
    return existsSync(TOKEN_CACHE) ? JSON.parse(readFileSync(TOKEN_CACHE, 'utf8')) : {};
  } catch {
    return {};
  }
};
const saveTokens = (cache) => {
  try {
    writeFileSync(TOKEN_CACHE, JSON.stringify(cache, null, 2));
  } catch {}
};

async function signIn(phone) {
  const cache = loadTokens();
  const cached = cache[phone];
  if (cached?.token) {
    const me = await api(cached.token, 'GET', '/auth/me');
    if (me.status === 200) return cached.token;
  }
  if (cached?.refresh) {
    const refreshed = await api(null, 'POST', '/auth/refresh-token', {
      refresh_token: cached.refresh,
    });
    const token = refreshed.body?.tokens?.access_token;
    if (token) {
      cache[phone] = {
        token,
        refresh: refreshed.body?.tokens?.refresh_token ?? cached.refresh,
      };
      saveTokens(cache);
      return token;
    }
  }

  const nonce = randomUUID();
  await api(null, 'POST', '/auth/otp/login/start', {
    phone,
    platform: 'web',
    client_nonce: nonce,
  });
  let code;
  for (let i = 0; i < 20 && !code; i += 1) {
    const inbox = await api(null, 'GET', '/auth/dev/inbox');
    code = (inbox.body?.messages ?? []).find(
      (m) => m.destination === phone && m.purpose === 'login',
    )?.code;
    if (!code) await new Promise((r) => setTimeout(r, 250));
  }
  if (!code) throw new Error(`no OTP for ${phone} — is OTP_DEV_INBOX_ENABLED set?`);
  const verify = await api(null, 'POST', '/auth/otp/login/verify', {
    phone,
    code,
    client_nonce: nonce,
    platform: 'web',
  });
  const token = verify.body?.tokens?.access_token;
  if (!token) throw new Error(`sign-in failed for ${phone}`);
  cache[phone] = { token, refresh: verify.body?.tokens?.refresh_token };
  saveTokens(cache);
  return token;
}

// ── The sandbox carrier ─────────────────────────────────────────────────

const carrier = {
  deliveries: new Map(),
  requests: [],
};

function startCarrier() {
  return new Promise((resolve) => {
    const server = createServer((req, res) => {
      let body = '';
      req.on('data', (chunk) => (body += chunk));
      req.on('end', () => {
        const payload = body ? JSON.parse(body) : {};
        carrier.requests.push({
          path: req.url,
          idempotencyKey: req.headers['idempotency-key'],
          authorization: req.headers.authorization,
          payload,
        });

        if (req.url === '/deliveries' && req.method === 'POST') {
          // Unique per run: a carrier that reused an id across runs would hit
          // the (provider, external_delivery_id) uniqueness — which is the
          // constraint doing its job, not something to test around.
          const id = `ACME-${RUN}-${carrier.deliveries.size + 1}`;
          carrier.deliveries.set(id, payload);
          res.writeHead(201, { 'Content-Type': 'application/json' });
          res.end(
            JSON.stringify({
              id,
              tracking_number: `AWB${100000 + carrier.deliveries.size}`,
              status: 'assigned',
              fee: '12000',
              currency: 'SYP',
            }),
          );
          return;
        }

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true }));
      });
    });
    server.listen(CARRIER_PORT, '127.0.0.1', () => resolve(server));
  });
}

async function callback(payload) {
  const raw = Buffer.from(JSON.stringify(payload));
  return fetch(`${BASE}/webhooks/delivery/${CODE}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-acme-signature': createHmac('sha256', WEBHOOK_SECRET)
        .update(raw)
        .digest('hex'),
    },
    body: raw,
  }).then(async (res) => ({ status: res.status, body: await res.json() }));
}

// ── The run ─────────────────────────────────────────────────────────────

const server = await startCarrier();
console.log(`\n=== delivery integration E2E — sandbox carrier on :${CARRIER_PORT} ===\n`);

const admin = await signIn(ADMIN);
const seller = await signIn(SELLER);
const buyer = await signIn(BUYER);

const state = {};

await step('admin registers the delivery company', async () => {
  const existing = expect(
    await api(admin, 'GET', '/admin/delivery/providers'),
    200,
    'GET providers',
  );
  const already = existing.find((row) => row.code === CODE);

  const payload = {
    code: CODE,
    adapter: 'http_generic',
    display_name: 'أكمي للتوصيل (تجريبي)',
    kind: 'EXTERNAL_API',
    priority: 10,
    is_default: true,
    governorates: [],
    supports_cancel: true,
    supports_tracking: true,
    supports_webhook: true,
    webhook_auth: 'HMAC_SHA256',
    webhook_signature_header: 'x-acme-signature',
    config: {
      baseUrl: `http://127.0.0.1:${CARRIER_PORT}`,
      createPath: '/deliveries',
      timeoutMs: 4000,
      retries: 1,
    },
    credential_env_keys: {
      apiKey: 'ACME_API_KEY',
      webhookSecret: 'ACME_WEBHOOK_SECRET',
    },
  };

  const account = already
    ? expect(
        await api(admin, 'PATCH', `/admin/delivery/providers/${already.id}`, payload),
        200,
        'PATCH provider',
      )
    : expect(
        await api(admin, 'POST', '/admin/delivery/providers', payload),
        [200, 201],
        'POST provider',
      );

  state.providerId = account.id;
  const enabled = expect(
    await api(admin, 'POST', `/admin/delivery/providers/${account.id}/enable`),
    200,
    'enable provider',
  );
  if (!enabled.is_enabled) throw new Error('the carrier did not enable');
  return `${enabled.display_name}, webhook ${enabled.webhook.url}`;
});

await step('the admin surface never returns a credential', async () => {
  const rows = expect(
    await api(admin, 'GET', '/admin/delivery/providers'),
    200,
    'GET providers',
  );
  const acme = rows.find((row) => row.code === CODE);
  const text = JSON.stringify(acme);
  if (text.includes(WEBHOOK_SECRET) || text.includes('sandbox-api-key')) {
    throw new Error('a secret value reached the admin payload');
  }
  const secretRow = acme.credentials.find((c) => c.field === 'webhookSecret');
  if (!secretRow?.is_set) throw new Error('the webhook secret is not set in the environment');
  return `${acme.credentials.length} credential(s) named, values withheld`;
});

await step('a buyer places an order', async () => {
  const addresses = expect(await api(buyer, 'GET', '/addresses'), 200, 'GET addresses');
  const address = (Array.isArray(addresses) ? addresses : addresses.items ?? [])[0];
  if (!address) throw new Error('the buyer has no saved address');

  await api(buyer, 'DELETE', '/cart');
  const products = expect(
    await api(buyer, 'GET', '/seller/offers?limit=1&page=1', undefined),
    [200, 403],
    'offers',
  );
  // The seller's own offers endpoint needs her token; use it to pick a live one.
  const offers = expect(
    await api(seller, 'GET', '/seller/offers?limit=5&page=1'),
    200,
    'GET /seller/offers',
  );
  const offer = (offers.data ?? offers.items ?? []).find((row) => row.stock > 0);
  if (!offer) throw new Error('the seller has no offer in stock');

  expect(
    await api(buyer, 'POST', '/cart/items', { offer_id: offer.id, quantity: 1 }),
    [200, 201],
    'POST /cart/items',
  );
  const checkout = expect(
    await api(buyer, 'POST', '/orders/checkout', {
      address_id: address.id,
      payment_method: 'COD',
    }),
    [200, 201],
    'POST /orders/checkout',
  );

  state.orderId = checkout.order?.id ?? checkout.id;
  if (checkout.cod_assurance?.required === 'order_confirmation') {
    let code;
    for (let i = 0; i < 20 && !code; i += 1) {
      const inbox = await api(null, 'GET', '/auth/dev/inbox');
      code = (inbox.body?.messages ?? []).find(
        (m) => m.destination === BUYER && m.purpose === 'order_confirmation',
      )?.code;
      if (!code) await new Promise((r) => setTimeout(r, 250));
    }
    expect(
      await api(buyer, 'POST', `/orders/${state.orderId}/cod-confirmation`, { code }),
      [200, 201],
      'cod confirmation',
    );
  }

  const detail = expect(
    await api(buyer, 'GET', `/orders/${state.orderId}`),
    200,
    'GET order',
  );
  state.sellerOrderId = (detail.seller_orders ?? [])[0]?.id;
  return `order ${detail.number ?? state.orderId}`;
});

await step('the seller packs it, and it goes to the carrier', async () => {
  expect(
    await api(seller, 'POST', `/seller/orders/${state.sellerOrderId}/confirm`, {}),
    [200, 201],
    'confirm',
  );
  const ready = expect(
    await api(seller, 'POST', `/seller/orders/${state.sellerOrderId}/ready`, {}),
    [200, 201],
    'ready',
  );

  state.trackingCode = ready.shipment?.tracking_code;
  const carrierBlock = ready.shipment?.carrier;
  if (!carrierBlock) throw new Error('no carrier on the packed parcel');
  if (carrierBlock.name.includes('أوهارا')) {
    throw new Error(`the parcel went to the in-house fleet, not to ${CODE}`);
  }

  const created = carrier.requests.find((r) => r.path === '/deliveries');
  if (!created) throw new Error('the carrier never received a create call');
  state.externalDeliveryId = [...carrier.deliveries.keys()].at(-1);
  if (!created.idempotencyKey) throw new Error('the create call carried no idempotency key');
  if (created.authorization !== 'Bearer sandbox-api-key') {
    throw new Error('the carrier did not receive its API key from the environment');
  }
  if (!created.payload.dropoff?.address_line) {
    throw new Error('the carrier was not told where to deliver');
  }

  return `${carrierBlock.name}, tracking ${carrierBlock.tracking_number}`;
});

await step('an unsigned callback changes nothing', async () => {
  const res = await fetch(`${BASE}/webhooks/delivery/${CODE}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      event_id: randomUUID(),
      delivery_id: state.externalDeliveryId,
      status: 'delivered',
    }),
  });
  const body = await res.json();
  if (res.status !== 200) throw new Error(`expected a 200 receipt, got ${res.status}`);
  if (body.accepted !== 0) throw new Error('an unsigned callback was applied');

  const order = expect(await api(buyer, 'GET', `/orders/${state.orderId}`), 200, 'GET order');
  const parcel = (order.seller_orders ?? [])[0];
  if (String(parcel.status).includes('delivered')) {
    throw new Error('an unsigned callback delivered the parcel');
  }
  return 'recorded, refused';
});

await step('the carrier collects the parcel', async () => {
  const res = await callback({
    event_id: randomUUID(),
    delivery_id: state.externalDeliveryId,
    status: 'picked_up',
    timestamp: new Date().toISOString(),
  });
  if (res.body.accepted !== 1) throw new Error(JSON.stringify(res.body));

  const order = expect(await api(buyer, 'GET', `/orders/${state.orderId}`), 200, 'GET order');
  const parcel = (order.seller_orders ?? [])[0];
  if (parcel.status !== 'handed_to_courier') {
    throw new Error(`the parcel reads ${parcel.status}`);
  }
  return parcel.status;
});

await step('the buyer’s tracking page names the carrier', async () => {
  const tracking = expect(
    await api(null, 'GET', `/shipments/track/${state.trackingCode}`),
    200,
    'GET tracking',
  );
  if (!tracking.carrier?.name) throw new Error('the tracking page names no carrier');
  if (!tracking.carrier.tracking_number) {
    throw new Error("the carrier's own number is missing");
  }
  return `${tracking.carrier.name} · ${tracking.carrier.tracking_number}`;
});

await step('out for delivery, then delivered', async () => {
  await callback({
    event_id: randomUUID(),
    delivery_id: state.externalDeliveryId,
    status: 'out_for_delivery',
  });
  const delivered = await callback({
    event_id: randomUUID(),
    delivery_id: state.externalDeliveryId,
    status: 'delivered',
    timestamp: new Date().toISOString(),
  });
  if (delivered.body.accepted !== 1) throw new Error(JSON.stringify(delivered.body));

  const order = expect(await api(buyer, 'GET', `/orders/${state.orderId}`), 200, 'GET order');
  const parcel = (order.seller_orders ?? [])[0];
  if (parcel.status !== 'delivered') throw new Error(`the parcel reads ${parcel.status}`);
  state.deliveredEvent = delivered;
  return `order ${order.status}`;
});

await step('a redelivered callback is ignored', async () => {
  // Same event id as the delivery above: carriers resend, and the second copy
  // must not settle anything twice.
  const repeat = await callback({
    event_id: 'fixed-duplicate-id',
    delivery_id: state.externalDeliveryId,
    status: 'delivered',
  });
  const again = await callback({
    event_id: 'fixed-duplicate-id',
    delivery_id: state.externalDeliveryId,
    status: 'delivered',
  });
  if (again.body.accepted !== 0) {
    throw new Error('a repeated event id was applied twice');
  }
  return `first=${repeat.body.accepted} second=${again.body.accepted}`;
});

await step('the return window opened on the carrier’s word', async () => {
  const eligibility = expect(
    await api(buyer, 'GET', `/returns/eligibility/${state.sellerOrderId}`),
    200,
    'GET eligibility',
  );
  if (!eligibility.is_window_open) {
    throw new Error('a delivery reported by a carrier did not open the return window');
  }
  return `closes ${eligibility.window_closes_at}`;
});

await step('ops can read the dispatch and its events', async () => {
  const list = expect(
    await api(admin, 'GET', `/admin/delivery/dispatches?provider=${CODE}&page=1&limit=5`),
    200,
    'GET dispatches',
  );
  const row = (list.data ?? [])[0];
  if (!row) throw new Error('the dispatch does not appear on the ops screen');
  const events = expect(
    await api(admin, 'GET', `/admin/delivery/dispatches/${row.id}/events`),
    200,
    'GET events',
  );
  const refused = events.filter((event) => event.signature_valid === false).length;
  if (refused < 1) throw new Error('the refused callback was not recorded');
  return `${events.length} event(s), ${refused} refused`;
});

// The sandbox carrier is a fixture, not a fixture of the platform: turn it off
// again so a later dispatch does not try to reach a server that has stopped.
await step('the carrier is disabled again', async () => {
  const disabled = expect(
    await api(admin, 'POST', `/admin/delivery/providers/${state.providerId}/disable`),
    200,
    'disable',
  );
  if (disabled.is_enabled) throw new Error('the carrier is still enabled');
  return 'in-house fleet takes over again';
});

server.close();
console.log(`\n${failures === 0 ? 'all steps passed' : `${failures} step(s) failed`}\n`);
process.exit(failures === 0 ? 0 : 1);
