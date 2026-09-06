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
