// Live chat through Supabase Realtime, end to end, against a deployed project.
//
//   SUPABASE_URL=… SUPABASE_PUBLISHABLE_KEY=… SUPABASE_TEST_OTPS="963933333333=…,963922222222=…" \
//   node scripts/realtime-test.mjs
//
// Two phones: the customer subscribes to her private topic exactly as the
// Flutter app does; the seller sends her a message through the API; the
// customer must receive `message.created` within seconds. Then the checks that
// matter as much: she cannot join the seller's topic, and she cannot publish a
// forged server event onto her own. Uses the platform's test phone numbers.
import { createClient } from '@supabase/supabase-js';

const URL_ = process.env.SUPABASE_URL.replace(/\/+$/, '');
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY;
const API = `${URL_}/functions/v1/api`;
const OTPS = Object.fromEntries(String(process.env.SUPABASE_TEST_OTPS ?? '').split(',').filter(Boolean).map((p) => p.split('=')));
const CUSTOMER = process.env.REEM_CUSTOMER ?? '963933333333';
const SELLER = process.env.REEM_SELLER ?? '963922222222';

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? ` — ${detail}` : ''}`);
};

async function api(method, path, token, body) {
  const response = await fetch(`${API}${path}`, {
    method,
    headers: { apikey: KEY, 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await response.json().catch(() => null);
  if (!response.ok) throw new Error(`${method} ${path} → ${response.status} ${JSON.stringify(json)}`);
  return json;
}

async function phone(bare) {
  const supabase = createClient(URL_, KEY, { auth: { persistSession: false, autoRefreshToken: false } });
  let { error } = await supabase.auth.signInWithOtp({ phone: bare });
  if (error) throw error;
  const verified = await supabase.auth.verifyOtp({ phone: bare, token: OTPS[bare], type: 'sms' });
  if (verified.error) throw verified.error;
  const accessToken = verified.data.session.access_token;
  const exchange = await api('POST', '/auth/supabase/exchange', null, { access_token: accessToken });
  const reemToken = exchange.tokens.access_token;
  await api('POST', '/auth/supabase/link', reemToken, { access_token: accessToken });
  await supabase.realtime.setAuth(accessToken);
  return { supabase, reemToken, userId: exchange.user.id, accessToken };
}

function subscribe(supabase, topic, onEvent) {
  return new Promise((resolve) => {
    const channel = supabase.channel(topic, { config: { private: true } });
    if (onEvent) channel.on('broadcast', { event: '*' }, onEvent);
    const timer = setTimeout(() => resolve({ channel, status: 'NO_ANSWER' }), 15000);
    channel.subscribe((status, error) => {
      if (status !== 'SUBSCRIBED' && status !== 'CHANNEL_ERROR' && status !== 'TIMED_OUT' && status !== 'CLOSED') return;
      clearTimeout(timer);
      resolve({ channel, status, error });
    });
  });
}

const customer = await phone(CUSTOMER);
const seller = await phone(SELLER);
console.log(`customer ${customer.userId} · seller ${seller.userId}`);

// The conversation between the two (created once, then reused).
const thread = await api('POST', '/chats', customer.reemToken, { seller_id: seller.userId });
const chatId = thread.id ?? thread.data?.id;
check('conversation resolved', Boolean(chatId), chatId);

// 1. Her own topic: she may join, and a message sent to her arrives.
let received = null;
const own = await subscribe(customer.supabase, `reem:user:${customer.userId}`, (message) => {
  if (message.event === 'message.created') received = message;
});
check('customer joins her private topic', own.status === 'SUBSCRIBED', own.error?.message ?? own.status);

const marker = `realtime-test ${Date.now()}`;
const sentAt = Date.now();
await api('POST', `/chats/${chatId}/messages`, seller.reemToken, { content: marker, client_id: `rt-${sentAt}` });
for (let waited = 0; waited < 15000 && !received; waited += 250) await new Promise((r) => setTimeout(r, 250));
const payload = received?.payload;
check(
  'message.created reaches the customer live',
  payload?.chat_id === chatId && JSON.stringify(payload?.message ?? {}).includes(marker),
  received ? `${Date.now() - sentAt} ms after send` : 'nothing within 15 s',
);

// 2. Someone else's topic: refused by RLS.
const foreign = await subscribe(customer.supabase, `reem:user:${seller.userId}`);
check("customer cannot join the seller's topic", foreign.status !== 'SUBSCRIBED', foreign.status);

// 3. Forging a server event on her own topic: publishing is refused. The
//    client reports "ok" for any unacknowledged send, so the test asks the
//    server to acknowledge, and also listens from a second connection.
let forgedSeen = false;
const listener = createClient(URL_, KEY, { auth: { persistSession: false, autoRefreshToken: false } });
await listener.realtime.setAuth(customer.accessToken);
const watch = await subscribe(listener, `reem:user:${customer.userId}`, (message) => {
  if (message.payload?.forged) forgedSeen = true;
});
const publisher = customer.supabase.channel(`reem:user:${customer.userId}`, { config: { private: true, broadcast: { ack: true } } });
await new Promise((resolve) => {
  const timer = setTimeout(resolve, 15000);
  publisher.subscribe((status) => {
    if (status === 'SUBSCRIBED' || status === 'CHANNEL_ERROR' || status === 'TIMED_OUT' || status === 'CLOSED') {
      clearTimeout(timer);
      resolve();
    }
  });
});
const forged = await Promise.race([new Promise((r) => setTimeout(() => r('no ack'), 10000)), publisher.send({ type: 'broadcast', event: 'message.created', payload: { forged: true } })]);
await new Promise((r) => setTimeout(r, 3000));
check(
  'customer cannot publish on her user topic',
  watch.status === 'SUBSCRIBED' && !forgedSeen,
  `ack=${forged}, delivered to listener=${forgedSeen}`,
);
await listener.removeAllChannels();

// 4. The conversation topic: members may join and send typing.
const chat = await subscribe(customer.supabase, `reem:chat:${chatId}`);
check('customer joins the conversation topic (typing)', chat.status === 'SUBSCRIBED', chat.status);

for (const client of [customer.supabase, seller.supabase]) await client.removeAllChannels();
console.log(`\n${results.filter(Boolean).length}/${results.length} passed`);
process.exit(results.every(Boolean) ? 0 : 1);
