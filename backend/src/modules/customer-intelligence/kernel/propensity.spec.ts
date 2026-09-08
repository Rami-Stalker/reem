import assert from 'node:assert/strict';
import test from 'node:test';

import { CustomerFacts } from './customer-facts';
import {
  VALUE_HORIZON_DAYS,
  cadenceOf,
  contactWindow,
  readCustomer,
  scoreChurn,
  scorePropensity,
  scoreValue,
} from './propensity';

/**
 * The scoring rules, pinned.
 *
 * The one that matters most is the rhythm rule: a customer is judged against
 * her own cadence, never against a fixed number of days. Almost every
 * marketplace ships the fixed rule, and it is wrong for one of the two
 * customers below whichever threshold it picks.
 */

const facts = (over: {
  purchases?: Partial<CustomerFacts['purchases']>;
  engagement?: Partial<CustomerFacts['engagement']>;
  rhythm?: Partial<CustomerFacts['rhythm']>;
} = {}): CustomerFacts => ({
  purchases: {
    orders: 0,
    lifetimeSpend: 0,
    daysSinceFirstOrder: null,
    daysSinceLastOrder: null,
    refundedOrders: 0,
    refundedSpend: 0,
    ...over.purchases,
  },
  engagement: {
    daysSinceLastSeen: 2,
    appOpens: 10,
    productViews: 20,
    searches: 3,
    cartAdds: 0,
    favourites: 0,
    windowDays: 30,
    hasOpenCart: false,
    accountAgeDays: 300,
    ...over.engagement,
  },
  rhythm: { activityByHour: new Array(24).fill(0), observations: 0, ...over.rhythm },
});

const codes = (signals: { code: string }[]) => signals.map((s) => s.code);

// ── Cadence ──────────────────────────────────────────────────────────────────

test('cadence is measured over the span she has been buying, not since signup', () => {
  // Six orders spread over 150 days: one every thirty.
  const cadence = cadenceOf({
    orders: 6,
    lifetimeSpend: 0,
    daysSinceFirstOrder: 160,
    daysSinceLastOrder: 10,
    refundedOrders: 0,
    refundedSpend: 0,
  });
  assert.equal(cadence, 30);
});

test('one order establishes no rhythm', () => {
  assert.equal(
    cadenceOf({
      orders: 1,
      lifetimeSpend: 0,
      daysSinceFirstOrder: 90,
      daysSinceLastOrder: 90,
      refundedOrders: 0,
      refundedSpend: 0,
    }),
    null,
  );
});

// ── The rule the whole file turns on ─────────────────────────────────────────

test('sixty days of silence means opposite things to two customers', () => {
  // She buys every three weeks, and has been quiet for sixty days.
  const frequent = scoreChurn(
    facts({
      purchases: {
        orders: 10,
        daysSinceFirstOrder: 249,
        daysSinceLastOrder: 60,
      },
      engagement: { daysSinceLastSeen: 60 },
    }),
  );

  // She buys twice a year, and has been quiet for sixty days.
  const occasional = scoreChurn(
    facts({
      purchases: {
        orders: 3,
        daysSinceFirstOrder: 425,
        daysSinceLastOrder: 60,
      },
      engagement: { daysSinceLastSeen: 60 },
    }),
  );

  assert.ok(
    frequent.score > occasional.score + 30,
    `the same sixty days must read very differently: ${frequent.score} vs ${occasional.score}`,
  );
  assert.equal(occasional.band, 'safe', 'she is not late by her own standard');
  assert.ok(['leaving', 'gone'].includes(frequent.band));
});

test('a customer on her own cadence is not flagged', () => {
  const reading = scoreChurn(
    facts({
      purchases: { orders: 8, daysSinceFirstOrder: 148, daysSinceLastOrder: 20 },
      engagement: { daysSinceLastSeen: 3 },
    }),
  );
  assert.equal(reading.band, 'safe');
  assert.ok(codes(reading.signals).includes('on_cadence'));
});

test('still visiting counts against churn even when overdue', () => {
  const base = {
    purchases: { orders: 6, daysSinceFirstOrder: 160, daysSinceLastOrder: 75 },
  };
  const browsing = scoreChurn(
    facts({ ...base, engagement: { daysSinceLastSeen: 2 } }),
  );
  const vanished = scoreChurn(
    facts({ ...base, engagement: { daysSinceLastSeen: 75 } }),
  );

  assert.ok(
    browsing.score < vanished.score,
    'a woman still opening the app is losing interest, not gone',
  );
  assert.ok(codes(browsing.signals).includes('still_visiting'));
});

test('somebody who never bought is not called churned', () => {
  const reading = scoreChurn(
    facts({ engagement: { daysSinceLastSeen: 120 } }),
  );
  assert.ok(codes(reading.signals).includes('never_purchased'));
  assert.equal(
    reading.confident,
    false,
    'sending a win-back offer to somebody never won is a different mistake',
  );
  assert.ok(reading.score <= 40);
});

test('a single order is scored, but not confidently', () => {
  const reading = scoreChurn(
    facts({
      purchases: { orders: 1, daysSinceFirstOrder: 100, daysSinceLastOrder: 100 },
      engagement: { daysSinceLastSeen: 100 },
    }),
  );
  assert.equal(reading.cadenceDays, null);
  assert.equal(reading.confident, false);
  assert.ok(codes(reading.signals).includes('no_cadence_yet'));
});

// ── Propensity ───────────────────────────────────────────────────────────────

test('an open cart is the strongest thing she can tell us', () => {
  const idle = scorePropensity(facts({ purchases: { orders: 2, daysSinceFirstOrder: 60, daysSinceLastOrder: 30 } }));
  const holding = scorePropensity(
    facts({
      purchases: { orders: 2, daysSinceFirstOrder: 60, daysSinceLastOrder: 30 },
      engagement: { hasOpenCart: true },
    }),
  );
  assert.ok(holding.score > idle.score + 20);
  assert.ok(codes(holding.signals).includes('open_cart'));
});

test('a customer due by her own rhythm reads warmer', () => {
  const due = scorePropensity(
    facts({
      purchases: { orders: 6, daysSinceFirstOrder: 160, daysSinceLastOrder: 30 },
    }),
  );
  assert.ok(codes(due.signals).includes('due_by_cadence'));
});

test('long overdue argues against buying, not for it', () => {
  const gone = scorePropensity(
    facts({
      purchases: { orders: 6, daysSinceFirstOrder: 250, daysSinceLastOrder: 150 },
      engagement: { daysSinceLastSeen: 150 },
    }),
  );
  assert.ok(codes(gone.signals).includes('long_overdue'));
  assert.equal(gone.band, 'cold');
});

test('a brand-new visitor is scored but not trusted', () => {
  const reading = scorePropensity(
    facts({
      engagement: {
        appOpens: 1,
        productViews: 2,
        searches: 0,
        cartAdds: 1,
        hasOpenCart: true,
        accountAgeDays: 0,
      },
    }),
  );
  assert.ok(reading.score > 30, 'the cart is real evidence');
  assert.equal(
    reading.confident,
    false,
    'and one session is not enough to spend money on',
  );
});

test('impressions are not counted as intent', () => {
  // There is deliberately no impression field: a card scrolling past says
  // something about the feed, not about her.
  const reading = scorePropensity(facts());
  assert.ok(!codes(reading.signals).some((code) => code.includes('impression')));
});

// ── Value ────────────────────────────────────────────────────────────────────

test('value is projected from her own cadence and her own basket', () => {
  const reading = scoreValue(
    facts({
      purchases: {
        orders: 6,
        lifetimeSpend: 600_000,
        daysSinceFirstOrder: 160,
        daysSinceLastOrder: 20,
        refundedOrders: 0,
      },
      engagement: { daysSinceLastSeen: 2 },
    }),
  );

  assert.equal(reading.realisedValue, 600_000);
  assert.equal(reading.averageOrder, 100_000);
  assert.equal(reading.horizonDays, VALUE_HORIZON_DAYS);
  // Six orders over 150 days is one every 30, so 180 days ahead is six more
  // at 100,000 each, discounted by a low churn score. Above her lifetime to
  // date, and correctly so: she has only been here 150 days.
  assert.ok(
    reading.projectedValue > 500_000 && reading.projectedValue < 700_000,
    `projection was ${reading.projectedValue}`,
  );
  assert.equal(reading.confident, true);
});

test('a customer about to leave is projected to be worth less', () => {
  const shape = {
    orders: 6,
    lifetimeSpend: 600_000,
    daysSinceFirstOrder: 160,
    refundedOrders: 0,
  };
  const active = scoreValue(
    facts({
      purchases: { ...shape, daysSinceLastOrder: 20 },
      engagement: { daysSinceLastSeen: 2 },
    }),
  );
  const leaving = scoreValue(
    facts({
      purchases: { ...shape, daysSinceLastOrder: 130 },
      engagement: { daysSinceLastSeen: 130 },
    }),
  );

  assert.ok(
    leaving.projectedValue < active.projectedValue,
    'survival has to enter the projection, or every lapsed customer looks rich',
  );
});

test('a serial returner is not a valuable customer', () => {
  const clean = scoreValue(
    facts({
      purchases: {
        orders: 8,
        lifetimeSpend: 800_000,
        daysSinceFirstOrder: 200,
        daysSinceLastOrder: 15,
        refundedOrders: 0,
        refundedSpend: 0,
      },
    }),
  );
  const returner = scoreValue(
    facts({
      purchases: {
        orders: 8,
        lifetimeSpend: 800_000,
        daysSinceFirstOrder: 200,
        daysSinceLastOrder: 15,
        refundedOrders: 7,
        refundedSpend: 700_000,
      },
    }),
  );

  assert.ok(
    returner.projectedValue < clean.projectedValue,
    'ranking a buy-and-return customer as valuable spends the retention budget ' +
      'in exactly the wrong place',
  );
});

test('somebody who has never bought is worth nothing yet, and says so', () => {
  const reading = scoreValue(facts());
  assert.equal(reading.realisedValue, 0);
  assert.equal(reading.averageOrder, null);
  assert.equal(reading.projectedValue, 0);
  assert.equal(reading.confident, false);
});

// ── When to reach her ────────────────────────────────────────────────────────

test('a thin histogram yields no best hour at all', () => {
  const hours = new Array(24).fill(0);
  hours[21] = 4;
  const window = contactWindow({ activityByHour: hours, observations: 4 });

  assert.equal(
    window.bestHour,
    null,
    'a best hour computed from four opens is a random hour with a justification',
  );
  assert.deepEqual(window.hours, []);
});

test('a real histogram yields the hours she is actually awake', () => {
  const hours = new Array(24).fill(0);
  hours[21] = 30;
  hours[22] = 24;
  hours[13] = 12;
  hours[3] = 1;
  const window = contactWindow({ activityByHour: hours, observations: 67 });

  assert.equal(window.bestHour, 21);
  assert.ok(window.hours.includes(22));
  assert.ok(
    !window.hours.includes(3),
    'one event at three in the morning is not a preference',
  );
});

// ── The whole reading ────────────────────────────────────────────────────────

test('one call answers all four questions consistently', () => {
  const reading = readCustomer(
    facts({
      purchases: {
        orders: 5,
        lifetimeSpend: 500_000,
        daysSinceFirstOrder: 130,
        daysSinceLastOrder: 10,
        refundedOrders: 0,
      },
      engagement: { hasOpenCart: true, daysSinceLastSeen: 1 },
      rhythm: {
        activityByHour: Object.assign(new Array(24).fill(0), { 20: 40 }),
        observations: 40,
      },
    }),
  );

  assert.equal(reading.churn.band, 'safe');
  assert.equal(reading.propensity.band, 'hot');
  assert.ok(reading.value.projectedValue > 0);
  assert.equal(reading.contact.bestHour, 20);
});
