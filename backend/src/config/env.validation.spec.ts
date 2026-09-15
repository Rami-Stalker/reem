import 'reflect-metadata';
import assert from 'node:assert/strict';
import test from 'node:test';

import { validateEnv } from './env.validation';

/**
 * The boot-time refusals are the only thing standing between a hurried deploy
 * and a production server that logs one-time codes, reflects any origin back
 * with credentials, signs tokens with a key published in this repository, or
 * lets a customer confirm her own payment. They are cheap to keep and
 * expensive to rediscover, so each one gets a case.
 */

/** A configuration that should boot: real secrets, named origins, nothing dev. */
const production: Record<string, unknown> = {
  NODE_ENV: 'production',
  PORT: '3000',
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db?schema=public',
  JWT_ACCESS_SECRET: 'a'.repeat(40),
  JWT_REFRESH_SECRET: 'b'.repeat(40),
  OTP_PEPPER: 'c'.repeat(40),
  GUEST_TOKEN_PEPPER: 'd'.repeat(40),
  OTP_DELIVERY_KEY: 'e'.repeat(40),
  TOTP_ENC_KEY: 'f'.repeat(40),
  MEDIA_PUBLIC_ORIGIN: 'https://cdn.reem.shop',
  CORS_ORIGINS: 'https://reem.shop',
  MEDIA_DRIVER: 'supabase',
  SUPABASE_URL: 'https://ref.supabase.co',
  SUPABASE_SECRET_KEY: 'sb_secret_test',
  SMS_GATEWAY_URL: 'https://sms.example.sy/send',
  SMS_GATEWAY_KEY: 'k'.repeat(24),
};

const refuses = (patch: Record<string, unknown>, pattern: RegExp) =>
  assert.throws(() => validateEnv({ ...production, ...patch }), pattern);

test('a correct production configuration boots', () => {
  assert.doesNotThrow(() => validateEnv({ ...production }));
});

test('the payment sandbox cannot be left on in production', () => {
  refuses(
    { PAYMENTS_SANDBOX_CONFIRMATION: 'true' },
    /PAYMENTS_SANDBOX_CONFIRMATION cannot be enabled in production/,
  );
});

test('production must name its CORS origins', () => {
  refuses({ CORS_ORIGINS: '*' }, /CORS_ORIGINS must name the allowed origins/);
  refuses({ CORS_ORIGINS: undefined }, /CORS_ORIGINS must name the allowed origins/);
  refuses({ CORS_ORIGINS: '  ' }, /CORS_ORIGINS must name the allowed origins/);
});

test('the published placeholder secrets are refused', () => {
  // Long enough and distinct, so every other rule is satisfied — which is
  // exactly why `cp .env.example .env` needed catching here.
  refuses(
    { JWT_ACCESS_SECRET: 'change-me-access-secret-min-32-chars-long' },
    /still the published placeholders: JWT_ACCESS_SECRET/,
  );
  refuses(
    { OTP_PEPPER: 'change-me-otp-pepper-min-32-characters-long' },
    /still the published placeholders: OTP_PEPPER/,
  );
});

test('the development OTP surfaces stay refused', () => {
  refuses({ OTP_DEV_ECHO: 'true' }, /OTP_DEV_ECHO cannot be enabled in production/);
  refuses(
    { OTP_DEV_INBOX_ENABLED: 'true' },
    /OTP_DEV_INBOX_ENABLED cannot be enabled in production/,
  );
});

test('none of this constrains a development configuration', () => {
  assert.doesNotThrow(() =>
    validateEnv({
      ...production,
      NODE_ENV: 'development',
      CORS_ORIGINS: '*',
      OTP_DEV_ECHO: 'true',
      PAYMENTS_SANDBOX_CONFIRMATION: 'true',
    }),
  );
});

test('Supabase storage needs the project URL and the secret key', () => {
  refuses(
    { MEDIA_DRIVER: 'supabase', SUPABASE_URL: undefined },
    /SUPABASE_URL must be set/,
  );
  refuses(
    { MEDIA_DRIVER: 'supabase', SUPABASE_SECRET_KEY: undefined },
    /SUPABASE_SECRET_KEY must be set/,
  );
  refuses(
    {
      MEDIA_DRIVER: 'supabase',
      SUPABASE_URL: 'https://ref.supabase.co',
      SUPABASE_SECRET_KEY: 'sb_publishable_abc',
    },
    /holds the publishable \(anon\) key/,
  );
  refuses(
    {
      MEDIA_DRIVER: 'supabase',
      SUPABASE_URL: 'http://ref.supabase.co',
      SUPABASE_SECRET_KEY: 'sb_secret_abc',
    },
    /must be the project's https:\/\/ origin/,
  );
  assert.doesNotThrow(() =>
    validateEnv({
      ...production,
      MEDIA_DRIVER: 'supabase',
      SUPABASE_URL: 'https://ref.supabase.co',
      SUPABASE_SECRET_KEY: 'sb_secret_abc',
    }),
  );
});

test('a Supabase database URL must use TLS, and pgbouncer mode on the transaction pooler', () => {
  const pooler = 'postgresql://postgres.ref:pw@aws-0-eu-central-1.pooler.supabase.com:6543/postgres';
  refuses({ DATABASE_URL: `${pooler}?sslmode=require` }, /without pgbouncer=true/);
  refuses({ DATABASE_URL: `${pooler}?pgbouncer=true` }, /without sslmode=require/);
  assert.doesNotThrow(() =>
    validateEnv({
      ...production,
      DATABASE_URL: `${pooler}?pgbouncer=true&sslmode=require&sslcert=./certs/supabase-root-2021.crt&sslaccept=strict`,
    }),
  );
});

test('production refuses to boot with no way to deliver a sign-in code', () => {
  refuses(
    { SMS_GATEWAY_URL: undefined, SMS_GATEWAY_KEY: undefined },
    /no OTP delivery provider is configured/,
  );
  // Half a provider is no provider.
  refuses({ SMS_GATEWAY_KEY: '' }, /no OTP delivery provider is configured/);
  assert.doesNotThrow(() =>
    validateEnv({
      ...production,
      SMS_GATEWAY_URL: undefined,
      SMS_GATEWAY_KEY: undefined,
      WHATSAPP_PHONE_NUMBER_ID: '1234567890',
      WHATSAPP_ACCESS_TOKEN: 'EAAG' + 'x'.repeat(40),
    }),
  );
});

test('production refuses uploads on a container disk', () => {
  refuses({ MEDIA_DRIVER: 'local' }, /MEDIA_DRIVER is local in production/);
  refuses({ MEDIA_DRIVER: undefined }, /MEDIA_DRIVER is local in production/);
  assert.doesNotThrow(() =>
    validateEnv({ ...production, MEDIA_DRIVER: 'local', MEDIA_LOCAL_PERSISTENT: 'true' }),
  );
});

test('a job trigger secret, when set, is long enough not to be guessed', () => {
  refuses({ JOBS_TRIGGER_SECRET: 'short' }, /JOBS_TRIGGER_SECRET/);
  assert.doesNotThrow(() => validateEnv({ ...production, JOBS_TRIGGER_SECRET: 's'.repeat(40) }));
});

test('on Render the public origin may come from RENDER_EXTERNAL_URL', () => {
  refuses({ MEDIA_PUBLIC_ORIGIN: undefined }, /MEDIA_PUBLIC_ORIGIN must be set in production/);
  assert.doesNotThrow(() =>
    validateEnv({
      ...production,
      MEDIA_PUBLIC_ORIGIN: undefined,
      RENDER_EXTERNAL_URL: 'https://reem-api.onrender.com',
    }),
  );
});
