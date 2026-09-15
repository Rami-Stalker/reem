// End-to-end smoke test of the Reem API as deployed on Supabase (or run locally).
//
//   node scripts/smoke-api.mjs --api https://<ref>.supabase.co/functions/v1/api \
//        --login supabase --supabase-url https://<ref>.supabase.co --publishable-key <key> \
//        --otp 123456 [--commerce]
//
//   node scripts/smoke-api.mjs --api http://127.0.0.1:8787/api --login dev-inbox --commerce
//
// Signs in as a customer, a seller and a staff member, then walks the API
// surface each role uses — catalogue, inventory, cart, orders, content,
// likes/comments, follows, chat, notifications, commissions, delivery, admin —
// and checks the answers: no 5xx anywhere, success where the role is allowed,
// 401/403 where it is not. `--commerce` also places and cancels a real
// cash-on-delivery order, so run it only against data you may write to.
//
// Login modes:
//   supabase   Supabase Auth phone OTP (use test phone numbers with a fixed
//              code, configured in the dashboard), then /auth/supabase/exchange.
//   dev-inbox  The backend's own OTP with OTP_DEV_INBOX_ENABLED (local only).

const args = Object.fromEntries(
  process.argv.slice(2).reduce((pairs, value, index, all) => {
    if (!value.startsWith('--')) return pairs;
    const next = all[index + 1];
    pairs.push([value.slice(2), next && !next.startsWith('--') ? next : true]);
    return pairs;
  }, []),
);

const API = String(args.api ?? 'http://127.0.0.1:8787/api').replace(/\/+$/, '');
const LOGIN = args.login ?? 'dev-inbox';
const SUPABASE_URL = args['supabase-url'] ? String(args['supabase-url']).replace(/\/+$/, '') : null;
const PUBLISHABLE_KEY = args['publishable-key'] ?? null;

// Per-number test codes: --otps "963933333333=123456,…" (or SUPABASE_TEST_OTPS).
const OTP_BY_PHONE = Object.fromEntries(String(args.otps ?? process.env.SUPABASE_TEST_OTPS ?? '').split(',').filter(Boolean).map((pair) => pair.split('=')));
const OTP = args.otp ?? '123456';
const COMMERCE = Boolean(args.commerce);
const ACCOUNTS = {
  customer: args.customer ?? '+963933333333',
  seller: args.seller ?? '+963922222222',
  staff: args.staff ?? '+963911111111',
};

const results = [];
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function call(method, path, { token, body, headers = {} } = {}) {
  const started = Date.now();
  const response = await fetch(`${API}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(PUBLISHABLE_KEY ? { apikey: PUBLISHABLE_KEY } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  return { status: response.status, json, text, ms: Date.now() - started };
}

function record(actor, label, response, expectation) {
  const ok =
    expectation === 'ok'
      ? response.status >= 200 && response.status < 300
      : expectation === 'denied'
        ? response.status === 401 || response.status === 403
        : expectation === 'any'
          ? response.status < 500
          : response.status === expectation;
  const detail = ok ? '' : ` ${response.text.slice(0, 160).replace(/\s+/g, ' ')}`;
  results.push({ actor, label, status: response.status, ms: response.ms, ok, expectation });
  const mark = ok ? 'PASS' : 'FAIL';
  console.log(`${mark}  ${actor.padEnd(9)} ${String(response.status).padEnd(4)} ${String(response.ms).padStart(5)}ms  ${label}${detail}`);
  return response;
}

// ── Sign-in ─────────────────────────────────────────────────────────────────

async function signInDevInbox(phone) {
  const start = await call('POST', '/auth/otp/login/start', { body: { phone } });
  if (start.status >= 300) throw new Error(`otp start for ${phone}: ${start.status} ${start.text}`);
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const inbox = await call('GET', '/auth/dev/inbox');
    const message = inbox.json?.messages?.find((m) => m.destination === phone && m.purpose === 'login' && m.code);
    if (message) {
      const verify = await call('POST', '/auth/otp/login/verify', { body: { phone, code: message.code } });
      if (!verify.json?.tokens?.access_token) throw new Error(`otp verify for ${phone}: ${verify.status} ${verify.text}`);
      return { token: verify.json.tokens.access_token, user: verify.json.user };
    }
    await sleep(500);
  }
  throw new Error(`no code reached the dev inbox for ${phone}`);
}

async function signInSupabase(phone) {
  if (!SUPABASE_URL || !PUBLISHABLE_KEY) throw new Error('--supabase-url and --publishable-key are required');
  const gotrue = async (path, body) => {
    const response = await fetch(`${SUPABASE_URL}/auth/v1${path}`, {
      method: 'POST',
      headers: { apikey: PUBLISHABLE_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const json = await response.json().catch(() => null);
    if (!response.ok) throw new Error(`auth${path} for ${phone}: ${response.status} ${JSON.stringify(json)}`);
    return json;
  };
  const bare = phone.replace(/^\+/, '');
  await gotrue('/otp', { phone: bare });
  const session = await gotrue('/verify', { type: 'sms', phone: bare, token: OTP_BY_PHONE[bare] ?? OTP });
  const exchange = await call('POST', '/auth/supabase/exchange', { body: { access_token: session.access_token } });
  record('auth', `exchange Supabase session for ${phone}`, exchange, 'ok');
  if (!exchange.json?.tokens?.access_token) throw new Error(`exchange for ${phone}: ${exchange.status} ${exchange.text}`);
  const token = exchange.json.tokens.access_token;
  record('auth', `link Supabase identity for ${phone}`, await call('POST', '/auth/supabase/link', { token, body: { access_token: session.access_token } }), 'ok');
  return { token, user: exchange.json.user, supabaseToken: session.access_token };
}

const signIn = LOGIN === 'supabase' ? signInSupabase : signInDevInbox;

// ── The walk ────────────────────────────────────────────────────────────────

const CUSTOMER_READS = [
  '/auth/me', '/users/me', '/users/me/overview', '/experience/me', '/auth/account', '/auth/devices', '/auth/sessions',
  '/products?limit=5', '/products/trending', '/categories', '/discovery/home', '/discovery/home-content',
  '/search/products?q=%D9%81%D8%B3%D8%AA%D8%A7%D9%86', '/search/suggestions?q=%D9%81', '/search/trending',
  '/content/feed', '/content/stories', '/content/reels', '/content/following', '/content/saved', '/stories', '/posts/feed',
  '/cart', '/orders', '/addresses', '/favorites', '/favorites/overview', '/favorites/collections',
  '/notifications', '/notifications/preferences', '/chats', '/returns', '/reputation/me/reviews',
  '/ledger/wallet', '/ledger/wallet/transactions', '/rewards', '/rewards/membership', '/finance/disputes',
  '/delivery/governorates', '/payments/methods', '/value', '/closet', '/rooms', '/market/drops', '/market/missions',
  '/visual-search/bootstrap', '/ai/stylist/bootstrap',
];

const SELLER_READS = [
  '/seller/offers', '/seller/offers/low-stock', '/seller/commerce/overview', '/seller/orders',
  '/commissions/seller/earnings', '/finance/seller/earnings', '/finance/seller/payouts', '/returns/seller',
  '/reputation/seller/reviews', '/seller/content/analytics/overview', '/content/mine', '/content/taggable-products',
  '/trends/seller/overview', '/seller/intelligence/health', '/seller/market/drops', '/auth/seller-verification/me',
];

const STAFF_READS = [
  '/admin/stats', '/admin/orders', '/admin/products', '/admin/users', '/admin/sellers', '/admin/commissions',
  '/admin/audit-logs', '/admin/delivery/providers', '/admin/delivery/dispatches', '/finance/admin/overview',
  '/commissions/admin/rules', '/admin/content', '/admin/content/reports', '/notifications/admin/campaigns',
  '/trends/admin/overview', '/admin/intelligence/briefing', '/admin/value/distribution', '/reputation/admin/moderation-queue',
];

async function main() {
  console.log(`API ${API} · login ${LOGIN}${COMMERCE ? ' · commerce writes ON' : ''}\n`);

  record('anon', 'health', await call('GET', '/health'), 'ok');
  record('anon', 'public catalogue', await call('GET', '/products?limit=3'), 'ok');
  record('anon', 'orders need a session', await call('GET', '/orders'), 'denied');
  record('anon', 'admin needs a session', await call('GET', '/admin/stats'), 'denied');
  record('anon', 'cron needs the secret', await call('POST', '/internal/cron/IdempotencySweeper.sweep'), 'denied');
  record('anon', 'SMS hook needs a signature', await call('POST', '/auth/supabase/send-sms-hook', { body: { sms: { otp: '1' } } }), 'denied');

  const customer = await signIn(ACCOUNTS.customer);
  const seller = await signIn(ACCOUNTS.seller);
  const staff = await signIn(ACCOUNTS.staff);

  for (const path of CUSTOMER_READS) record('customer', `GET ${path}`, await call('GET', path, { token: customer.token }), 'ok');
  for (const path of SELLER_READS) record('seller', `GET ${path}`, await call('GET', path, { token: seller.token }), 'ok');
  // Staff routes may legitimately demand TOTP (AAL2) from an account that has
  // not enrolled one; "any" asserts only that nothing crashed.
  for (const path of STAFF_READS) record('staff', `GET ${path}`, await call('GET', path, { token: staff.token }), 'any');

  // Role boundaries.
  record('customer', 'cannot open the admin console', await call('GET', '/admin/stats', { token: customer.token }), 'denied');
  record('customer', 'cannot manage seller offers', await call('GET', '/seller/offers', { token: customer.token }), 'denied');
  record('seller', 'cannot open the admin console', await call('GET', '/admin/users', { token: seller.token }), 'denied');

  // Social writes, each undone.
  const feed = await call('GET', '/content/feed', { token: customer.token });
  const firstContent = (feed.json?.data ?? feed.json?.items ?? [])[0];
  if (firstContent?.id) {
    record('customer', 'like content', await call('POST', `/content/${firstContent.id}/like`, { token: customer.token }), 'ok');
    record('customer', 'unlike content', await call('POST', `/content/${firstContent.id}/like`, { token: customer.token }), 'ok');
    const comment = record('customer', 'comment on content', await call('POST', `/content/${firstContent.id}/comments`, { token: customer.token, body: { body: 'تجربة ✨ smoke test' } }), 'ok');
    const commentId = comment.json?.id ?? comment.json?.comment?.id;
    if (commentId) record('customer', 'delete own comment', await call('DELETE', `/content/comments/${commentId}`, { token: customer.token }), 'ok');
  }
  if (seller.user?.id) {
    record('customer', 'follow a seller', await call('POST', `/users/${seller.user.id}/follow`, { token: customer.token }), 'any');
    record('customer', 'unfollow a seller', await call('DELETE', `/users/${seller.user.id}/follow`, { token: customer.token }), 'any');
  }

  // Favourites and cart.
  const catalogue = await call('GET', '/products?limit=10', { token: customer.token });
  const product = (catalogue.json?.data ?? []).find((p) => (p.offers ?? [p.best_offer]).some((o) => o?.id));
  if (product) {
    record('customer', 'favourite a product', await call('POST', `/favorites/${product.id}`, { token: customer.token }), 'any');
    record('customer', 'unfavourite a product', await call('DELETE', `/favorites/${product.id}`, { token: customer.token }), 'any');
  }

  // Chat.
  const chats = await call('GET', '/chats', { token: customer.token });
  const chat = (chats.json?.data ?? chats.json ?? [])[0];
  if (chat?.id) {
    record('customer', 'read a chat thread', await call('GET', `/chats/${chat.id}/messages`, { token: customer.token }), 'ok');
    record('customer', 'send a chat message', await call('POST', `/chats/${chat.id}/messages`, { token: customer.token, body: { content: 'رسالة اختبار — smoke test', client_id: `smoke-${Date.now()}` } }), 'ok');
    record('customer', 'mark chat read', await call('PATCH', `/chats/${chat.id}/read`, { token: customer.token, body: {} }), 'ok');
  }
  record('customer', 'presence online', await call('POST', '/realtime/presence', { token: customer.token, body: { status: 'online' } }), 'ok');
  record('customer', 'presence offline', await call('POST', '/realtime/presence', { token: customer.token, body: { status: 'offline' } }), 'ok');

  if (COMMERCE && product) {
    const offer = (product.offers ?? [product.best_offer]).find((o) => o?.id);
    record('customer', 'clear cart', await call('DELETE', '/cart', { token: customer.token }), 'any');
    record('customer', 'add to cart', await call('POST', '/cart/items', { token: customer.token, body: { offer_id: offer.id, quantity: 1 } }), 'ok');
    const addresses = await call('GET', '/addresses', { token: customer.token });
    const address = (addresses.json?.data ?? addresses.json ?? [])[0];
    const order = record('customer', 'checkout (cash on delivery)', await call('POST', '/orders/checkout', {
      token: customer.token,
      body: { payment_method: 'COD', ...(address?.id ? { address_id: address.id } : {}), notes: 'smoke test — cancelled immediately' },
      headers: { 'Idempotency-Key': `smoke-${Date.now()}` },
    }), 'ok');
    const orderId = order.json?.id ?? order.json?.order?.id;
    if (orderId) {
      record('customer', 'order detail', await call('GET', `/orders/${orderId}`, { token: customer.token }), 'ok');
      record('seller', 'sees sub-orders', await call('GET', '/seller/orders', { token: seller.token }), 'ok');
      record('customer', 'cancel the order', await call('POST', `/orders/${orderId}/cancel`, { token: customer.token, body: { reason: 'smoke test' } }), 'any');
    }
  }

  record('customer', 'mark notifications read', await call('POST', '/notifications/read-all', { token: customer.token }), 'ok');

  const failed = results.filter((r) => !r.ok);
  const slowest = [...results].sort((a, b) => b.ms - a.ms).slice(0, 5);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  console.log(`slowest: ${slowest.map((r) => `${r.label} ${r.ms}ms`).join(' · ')}`);
  if (failed.length) {
    console.log('\nFailures:');
    for (const f of failed) console.log(`  ${f.actor} ${f.label} → ${f.status} (expected ${f.expectation})`);
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
