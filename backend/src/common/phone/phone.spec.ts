import assert from 'node:assert/strict';
import test from 'node:test';
import { foldDigits, isE164, normalizePhone } from './phone';

test('folds Arabic-Indic and Persian digits to ASCII', () => {
  assert.equal(foldDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
  assert.equal(foldDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
  assert.equal(foldDigits('09١٢345678'), '0912345678');
});

test('every way a Syrian number is written resolves to one identity', () => {
  const canonical = '+963912345678';
  for (const written of [
    '0912345678',
    '٠٩١٢٣٤٥٦٧٨',
    '۰۹۱۲۳۴۵۶۷۸',
    '00963912345678',
    '963912345678',
    '912345678',
    '+963 912 345 678',
    '+963-912-345-678',
    ' +963912345678 ',
  ]) {
    assert.equal(
      normalizePhone(written),
      canonical,
      `${written} should normalise to ${canonical}`,
    );
  }
});

test('numbers already in international form are kept as they are', () => {
  assert.equal(normalizePhone('+966500000001'), '+966500000001');
  assert.equal(normalizePhone('+966 50 000 0001'), '+966500000001');
});

test('rejects what cannot be a mobile number', () => {
  for (const invalid of [
    '',
    'abc',
    '+96391234', // too short
    '+963812345678', // not a Syrian mobile prefix
    '0501234567', // local form is resolved against Syria, and +9635… is invalid
    '+0123456789', // country codes do not start with zero
    null,
    undefined,
    12345,
  ]) {
    assert.equal(normalizePhone(invalid as string), null, `${invalid}`);
  }
});

test('isE164 accepts only the canonical form', () => {
  assert.equal(isE164('+963912345678'), true);
  assert.equal(isE164('0912345678'), false);
  assert.equal(isE164('963912345678'), false);
});
