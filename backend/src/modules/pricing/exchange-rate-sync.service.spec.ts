import assert from 'node:assert/strict';
import test from 'node:test';
import { Prisma } from '@prisma/client';

import {
  ExchangeRateSyncService,
  FxSyncConfig,
} from './exchange-rate-sync.service';

const Decimal = Prisma.Decimal;

/**
 * The guards around an automatic rate feed.
 *
 * A published rate reprices every USD-listed product on the platform, so these
 * checks are the difference between a feed that helps and one that quietly
 * doubles every price overnight. Tested on the prototype — no HTTP, no DI.
 */
const service = Object.create(ExchangeRateSyncService.prototype) as {
  readPath(body: unknown, path: string): unknown;
  moveInBps(previous: Prisma.Decimal, next: Prisma.Decimal): number;
};

/** `ExchangeRate.rate` is `@db.Decimal(18, 6)`. */
const STORED_DECIMALS = 6;

const config = (overrides: Partial<FxSyncConfig> = {}): FxSyncConfig => ({
  syncEnabled: true,
  sourceUrl: 'https://example.invalid/rate',
  sourcePath: 'rate',
  sourceName: 'test',
  maxMoveBps: 2500,
  minRate: '500',
  maxRate: '100000',
  ...overrides,
});

// ── Reading the feed ──────────────────────────────────────────────────────

test('a dotted path reads a nested rate', () => {
  const body = { usd: { ask: '15250', bid: '15100' } };
  assert.equal(service.readPath(body, 'usd.ask'), '15250');
  assert.equal(service.readPath(body, 'usd.bid'), '15100');
});

test('a path that does not exist reads as undefined, not a crash', () => {
  // The feed's shape changes without notice; a missing key must be a rejected
  // sync, not an exception into the scheduler.
  const body = { usd: { ask: '15250' } };
  assert.equal(service.readPath(body, 'usd.mid'), undefined);
  assert.equal(service.readPath(body, 'eur.ask'), undefined);
  assert.equal(service.readPath(body, 'a.b.c.d'), undefined);
});

test('a path never walks into a non-object', () => {
  assert.equal(service.readPath({ rate: '15000' }, 'rate.nested'), undefined);
  assert.equal(service.readPath(null, 'rate'), undefined);
  assert.equal(service.readPath('15000', 'rate'), undefined);
});

// ── Move detection ────────────────────────────────────────────────────────

test('a move is measured in basis points, signed', () => {
  // 15,000 → 15,750 is +5%.
  assert.equal(
    service.moveInBps(new Decimal('15000'), new Decimal('15750')),
    500,
  );
  // …and back down is −4.76%.
  assert.equal(
    service.moveInBps(new Decimal('15750'), new Decimal('15000')),
    -476,
  );
});

test('an unchanged rate moves zero', () => {
  assert.equal(
    service.moveInBps(new Decimal('15000'), new Decimal('15000')),
    0,
  );
});

test('a move from zero does not divide by zero', () => {
  assert.equal(service.moveInBps(new Decimal('0'), new Decimal('15000')), 0);
});

test('a doubled rate is far past the default limit', () => {
  // The scrape failure this guard exists for: a feed returning 30,000 when the
  // rate is 15,000 would double every USD-listed price on the platform.
  const move = service.moveInBps(new Decimal('15000'), new Decimal('30000'));
  assert.equal(move, 10000, 'doubling is 10,000 bps');
  assert.ok(
    Math.abs(move) > config().maxMoveBps,
    'and must exceed the publish limit',
  );
});

test('an ordinary daily drift passes the limit', () => {
  // A 2% day is normal for the SYP and must not need a human.
  const move = service.moveInBps(new Decimal('15000'), new Decimal('15300'));
  assert.equal(move, 200);
  assert.ok(Math.abs(move) <= config().maxMoveBps);
});

test('a sharp but genuine devaluation is held for a human', () => {
  // 30% down in a day is plausible in Syria and is exactly the case where
  // someone should look before the whole catalogue reprices.
  const move = service.moveInBps(new Decimal('15000'), new Decimal('10500'));
  assert.equal(move, -3000);
  assert.ok(Math.abs(move) > config().maxMoveBps);
});

// ── Bounds ────────────────────────────────────────────────────────────────

test('the configured bounds bracket a plausible SYP rate', () => {
  const fx = config();
  const min = new Decimal(fx.minRate);
  const max = new Decimal(fx.maxRate);

  // A real rate sits inside…
  assert.ok(new Decimal('15000').greaterThan(min));
  assert.ok(new Decimal('15000').lessThan(max));

  // …while the shapes a broken parse produces sit outside.
  assert.ok(new Decimal('0.15').lessThan(min), 'a decimal-shifted rate');
  assert.ok(new Decimal('1520000000').greaterThan(max), 'a concatenated one');
});

// ── Precision ─────────────────────────────────────────────────────────────

test('a fetched rate is compared at the precision the column stores', () => {
  // The feed quotes more decimals than the column keeps. Comparing the raw
  // fetch against the truncated stored value never matches, so an unchanged
  // rate would be republished on every run and the history would fill with
  // rows recording nothing.
  const fetched = new Decimal('13014.82693639');
  const stored = new Decimal('13014.826936');

  assert.equal(fetched.equals(stored), false, 'raw precision differs');
  assert.equal(
    fetched.toDecimalPlaces(STORED_DECIMALS).equals(stored),
    true,
    'quantised to the stored scale they are the same rate',
  );
  assert.equal(service.moveInBps(stored, fetched.toDecimalPlaces(STORED_DECIMALS)), 0);
});

test('the chosen feed quotes the parallel market, not the official rate', () => {
  // Syria's official rate sits near 2,000 SYP/USD while the market this
  // platform prices against is near 13,000. A feed quoting the former would
  // reprice the whole USD-listed catalogue by more than six times — the move
  // guard refuses it, which is how the wrong source was caught.
  const market = new Decimal('13014.826936');
  const official = new Decimal('2002.246466');

  const move = service.moveInBps(market, official);
  assert.ok(
    Math.abs(move) > 2500,
    'swapping to the official rate must exceed the publish limit',
  );
});
