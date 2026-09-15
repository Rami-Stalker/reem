// Storage and the Send SMS hook, against a deployed project.
//
//   SUPABASE_URL=… SUPABASE_PUBLISHABLE_KEY=… SUPABASE_TEST_OTPS=… SEND_SMS_HOOK_SECRET=… \
//   node scripts/storage-hook-test.mjs
//
// Storage: a public upload is readable at its CDN URL by anyone; a private
// upload is readable only through the API by its owner — not anonymously, not
// by another signed-in user, and not straight from Storage with the key every
// app carries. Uploads left unattached are removed by the media sweeper.
//
// Hook: an unsigned or wrongly signed call is refused; a correctly signed one
// reaches delivery (which answers 503 until a WhatsApp/SMS provider is set).
import { createHmac, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const URL_ = process.env.SUPABASE_URL.replace(/\/+$/, '');
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY;
const API = `${URL_}/functions/v1/api`;
const OTPS = Object.fromEntries(String(process.env.SUPABASE_TEST_OTPS ?? '').split(',').filter(Boolean).map((p) => p.split('=')));
const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? ` — ${detail}` : ''}`);
};

async function signIn(bare) {
  const gotrue = (p, body) =>
    fetch(`${URL_}/auth/v1${p}`, { method: 'POST', headers: { apikey: KEY, 'content-type': 'application/json' }, body: JSON.stringify(body) }).then((r) => r.json());
  await gotrue('/otp', { phone: bare });
  const session = await gotrue('/verify', { type: 'sms', phone: bare, token: OTPS[bare] });
  const exchange = await fetch(`${API}/auth/supabase/exchange`, {
    method: 'POST',
    headers: { apikey: KEY, 'content-type': 'application/json' },
    body: JSON.stringify({ access_token: session.access_token }),
  }).then((r) => r.json());
  return exchange.tokens.access_token;
}

async function upload(token, purpose, bytes) {
  const form = new FormData();
  form.append('purpose', purpose);
  form.append('file', new Blob([bytes], { type: 'image/jpeg' }), 'storage-test.jpg');
  const response = await fetch(`${API}/media/uploads`, { method: 'POST', headers: { apikey: KEY, authorization: `Bearer ${token}` }, body: form });
  return { status: response.status, json: await response.json().catch(() => null) };
}

const photo = readFileSync(path.resolve(here, '../../../backend/storage/media/public/2026/09/cd7be88a-002b-4219-9881-18ff5c352137.jpg'));
const customer = await signIn('963933333333');
const seller = await signIn('963922222222');

// Public ----------------------------------------------------------------------
const pub = await upload(customer, 'post', photo);
check('public upload accepted', pub.status === 201, `${pub.status}`);
const publicUrl = pub.json?.url;
check('public URL is served by Supabase Storage', typeof publicUrl === 'string' && publicUrl.includes('/storage/v1/object/public/reem-media-public/'), publicUrl);
const publicGet = await fetch(publicUrl);
const publicBytes = new Uint8Array(await publicGet.arrayBuffer());
check('public file readable anonymously, bytes intact', publicGet.ok && publicBytes.length === photo.length, `${publicGet.status}, ${publicBytes.length}/${photo.length} bytes`);

// Private ---------------------------------------------------------------------
const priv = await upload(customer, 'chat', photo);
check('private upload accepted', priv.status === 201, `${priv.status}`);
const privateUrl = priv.json?.url;
check('private URL goes through the API, not Storage', typeof privateUrl === 'string' && privateUrl.startsWith(`${API}/media/`), privateUrl);

const anonymous = await fetch(privateUrl, { headers: { apikey: KEY } });
check('private file refused without a session', anonymous.status === 401, `${anonymous.status}`);

const owner = await fetch(privateUrl, { headers: { apikey: KEY, authorization: `Bearer ${customer}` } });
const ownerBytes = new Uint8Array(await owner.arrayBuffer());
check('private file served to its owner', owner.ok && ownerBytes.length === photo.length, `${owner.status}, ${ownerBytes.length} bytes`);

const stranger = await fetch(privateUrl, { headers: { apikey: KEY, authorization: `Bearer ${seller}` } });
check('private file refused to another user', stranger.status === 403 || stranger.status === 404, `${stranger.status}`);

const storageKey = priv.json?.storage_key ?? priv.json?.key;
const listing = await fetch(`${URL_}/storage/v1/object/list/reem-media-private`, {
  method: 'POST',
  headers: { apikey: KEY, authorization: `Bearer ${KEY}`, 'content-type': 'application/json' },
  body: JSON.stringify({ prefix: '', limit: 10 }),
});
const listed = await listing.json().catch(() => null);
check('private bucket cannot be listed with the app key', !Array.isArray(listed) || listed.length === 0, `${listing.status} ${JSON.stringify(listed).slice(0, 60)}`);
if (storageKey) {
  const direct = await fetch(`${URL_}/storage/v1/object/reem-media-private/${storageKey}`, { headers: { apikey: KEY, authorization: `Bearer ${KEY}` } });
  check('private object not readable straight from Storage', !direct.ok, `${direct.status}`);
}
const directUpload = await fetch(`${URL_}/storage/v1/object/reem-media-public/${new Date().getFullYear()}/intruder-${randomUUID()}.jpg`, {
  method: 'POST',
  headers: { apikey: KEY, authorization: `Bearer ${KEY}`, 'content-type': 'image/jpeg' },
  body: photo,
});
check('nobody uploads to the public bucket directly', !directUpload.ok, `${directUpload.status}`);

// Send SMS hook -----------------------------------------------------------------
const hookUrl = `${API}/auth/supabase/send-sms-hook`;
const body = JSON.stringify({ user: { phone: '963933333333' }, sms: { otp: '000000' } });
const unsigned = await fetch(hookUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body });
check('hook refuses an unsigned call', unsigned.status === 401, `${unsigned.status}`);

const id = `msg_${randomUUID()}`;
const timestamp = String(Math.floor(Date.now() / 1000));
const badSignature = await fetch(hookUrl, {
  method: 'POST',
  headers: { 'content-type': 'application/json', 'webhook-id': id, 'webhook-timestamp': timestamp, 'webhook-signature': 'v1,AAAA' },
  body,
});
check('hook refuses a wrong signature', badSignature.status === 401, `${badSignature.status}`);

const secret = Buffer.from(process.env.SEND_SMS_HOOK_SECRET.replace(/^v1,whsec_/, ''), 'base64');
const signature = createHmac('sha256', secret).update(`${id}.${timestamp}.${body}`).digest('base64');
const signed = await fetch(hookUrl, {
  method: 'POST',
  headers: { 'content-type': 'application/json', 'webhook-id': id, 'webhook-timestamp': timestamp, 'webhook-signature': `v1,${signature}` },
  body,
});
const signedJson = await signed.json().catch(() => null);
check(
  'hook accepts a correctly signed call and reaches delivery',
  signed.status === 200 || (signed.status === 503 && /delivery channel/i.test(JSON.stringify(signedJson))),
  `${signed.status} ${JSON.stringify(signedJson)}`,
);

console.log(`\n${results.filter(Boolean).length}/${results.length} passed`);
process.exit(results.every(Boolean) ? 0 : 1);
