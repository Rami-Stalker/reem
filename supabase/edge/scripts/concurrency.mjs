// Many devices at once: several signed-in women and guests hitting the API in
// parallel, the way a busy evening looks.
//
//   node scripts/concurrency.mjs --api <base> --login dev-inbox|supabase [--devices 30] [--rounds 5] …
//
// Each "device" is an independent client with its own session, walking a mix
// of catalogue, feed, cart, chat and order screens concurrently with every
// other device. Reports throughput, latency percentiles and any non-2xx
// answers. Shares sign-in options with smoke-api.mjs.
const args = Object.fromEntries(
  process.argv.slice(2).reduce((pairs, value, index, all) => {
    if (!value.startsWith('--')) return pairs;
    const next = all[index + 1];
    pairs.push([value.slice(2), next && !next.startsWith('--') ? next : true]);
    return pairs;
  }, []),
);
const API = String(args.api ?? 'http://127.0.0.1:8787/api').replace(/\/+$/, '');
const DEVICES = Number(args.devices ?? 30);
const ROUNDS = Number(args.rounds ?? 5);
const PUBLISHABLE_KEY = args['publishable-key'] ?? null;

// Per-number test codes: --otps "963933333333=123456,…" (or SUPABASE_TEST_OTPS).
const OTP_BY_PHONE = Object.fromEntries(String(args.otps ?? process.env.SUPABASE_TEST_OTPS ?? '').split(',').filter(Boolean).map((pair) => pair.split('=')));

async function call(path, token) {
  const started = performance.now();
  try {
    const response = await fetch(`${API}${path}`, {
      headers: {
        Accept: 'application/json',
        ...(PUBLISHABLE_KEY ? { apikey: PUBLISHABLE_KEY } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
    });
    await response.arrayBuffer();
    return { status: response.status, ms: performance.now() - started, path };
  } catch (error) {
    return { status: 0, ms: performance.now() - started, path, error: String(error) };
  }
}

async function signIn(phone) {
  if (args.login === 'supabase') {
    const url = String(args['supabase-url']).replace(/\/+$/, '');
    const bare = phone.replace(/^\+/, '');
    const gotrue = (path, body) =>
      fetch(`${url}/auth/v1${path}`, {
        method: 'POST',
        headers: { apikey: PUBLISHABLE_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }).then((r) => r.json());
    await gotrue('/otp', { phone: bare });
    const session = await gotrue('/verify', { type: 'sms', phone: bare, token: OTP_BY_PHONE[bare] ?? args.otp ?? '123456' });
    const exchange = await fetch(`${API}/auth/supabase/exchange`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(PUBLISHABLE_KEY ? { apikey: PUBLISHABLE_KEY } : {}) },
      body: JSON.stringify({ access_token: session.access_token }),
    }).then((r) => r.json());
    return exchange.tokens.access_token;
  }
  await fetch(`${API}/auth/otp/login/start`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone }),
  });
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const inbox = await fetch(`${API}/auth/dev/inbox`).then((r) => r.json());
    const message = inbox.messages?.find((m) => m.destination === phone && m.purpose === 'login');
    if (message?.code) {
      const verify = await fetch(`${API}/auth/otp/login/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, code: message.code }),
      }).then((r) => r.json());
      return verify.tokens.access_token;
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`no code for ${phone}`);
}

const SCREENS = {
  guest: ['/products?limit=20', '/categories', '/discovery/home', '/content/feed', '/search/products?q=%D9%81%D8%B3%D8%AA%D8%A7%D9%86'],
  customer: ['/auth/me', '/discovery/home', '/content/feed', '/cart', '/orders', '/chats', '/notifications', '/favorites', '/products?limit=20'],
  seller: ['/auth/me', '/seller/orders', '/seller/offers', '/seller/commerce/overview', '/commissions/seller/earnings', '/chats'],
  staff: ['/admin/stats', '/admin/orders', '/admin/users', '/admin/delivery/dispatches'],
};

async function main() {
  const tokens = {
    customer: await signIn(args.customer ?? '+963933333333'),
    seller: await signIn(args.seller ?? '+963922222222'),
    staff: await signIn(args.staff ?? '+963911111111'),
    guest: null,
  };
  const roles = ['guest', 'customer', 'customer', 'seller', 'guest', 'customer', 'staff'];

  const started = performance.now();
  const results = (
    await Promise.all(
      Array.from({ length: DEVICES }, async (_, device) => {
        const role = roles[device % roles.length];
        const out = [];
        for (let round = 0; round < ROUNDS; round += 1) {
          // A screen's worth of requests fires together, as a screen does.
          out.push(...(await Promise.all(SCREENS[role].map((path) => call(path, tokens[role])))));
        }
        return out;
      }),
    )
  ).flat();
  const elapsed = (performance.now() - started) / 1000;

  const ms = results.map((r) => r.ms).sort((a, b) => a - b);
  const pct = (p) => ms[Math.min(ms.length - 1, Math.floor((p / 100) * ms.length))].toFixed(0);
  const failures = results.filter((r) => r.status < 200 || r.status >= 300);
  console.log(`${DEVICES} devices × ${ROUNDS} rounds = ${results.length} requests in ${elapsed.toFixed(1)}s (${(results.length / elapsed).toFixed(1)} req/s)`);
  console.log(`latency p50 ${pct(50)}ms · p95 ${pct(95)}ms · p99 ${pct(99)}ms · max ${ms[ms.length - 1].toFixed(0)}ms`);
  if (failures.length) {
    const byStatus = {};
    for (const f of failures) byStatus[`${f.status} ${f.path}`] = (byStatus[`${f.status} ${f.path}`] ?? 0) + 1;
    console.log(`${failures.length} non-2xx:`, byStatus);
    process.exitCode = 1;
  } else {
    console.log('no errors');
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
