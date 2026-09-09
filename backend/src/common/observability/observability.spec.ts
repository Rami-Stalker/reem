import assert from 'node:assert/strict';
import test from 'node:test';

import { RequestContextMiddleware } from './request-context.middleware';
import {
  currentRequestId,
  newRequestId,
  runWithRequestContext,
} from './request-context';
import { StructuredLogger } from './structured-logger';

/**
 * Whether a log line can be traced back to the woman who hit the problem.
 *
 * The platform runs one process, so every customer's work is interleaved in
 * one stream. Nest's default logger writes a coloured sentence with nothing
 * tying it to a request, which turns "her order failed at about four" into
 * reading a wall of lines and guessing.
 */

function middlewareRun(headers: Record<string, string> = {}) {
  const middleware = new RequestContextMiddleware();
  const request = { method: 'POST', path: '/orders/checkout', headers } as never;
  const headersSet: Record<string, string> = {};
  const response = {
    setHeader: (name: string, value: string) => {
      headersSet[name] = value;
    },
  } as never;

  let seen: string | undefined;
  middleware.use(request, response, () => {
    seen = currentRequestId();
  });
  return {
    seen,
    headersSet,
    attached: (request as { requestContext?: { requestId: string } })
      .requestContext,
  };
}

// ── The id ──────────────────────────────────────────────────────────────

test('a request id is short enough to read aloud', () => {
  const id = newRequestId();
  assert.match(id, /^[0-9a-f]{10}$/);
});

test('every request gets one, and the response carries it', () => {
  const { seen, headersSet, attached } = middlewareRun();
  assert.ok(seen, 'the work inside the request can reach its own id');
  assert.equal(headersSet['X-Request-Id'], seen);
  assert.equal(attached?.requestId, seen, 'and so can the exception filter');
});

test('a sensible inbound id is kept so one trace survives a hop', () => {
  const { seen } = middlewareRun({ 'x-request-id': 'edge-abc123' });
  assert.equal(seen, 'edge-abc123');
});

test('a hostile inbound id is replaced rather than echoed', () => {
  // The value is written into a response header and into logs. A caller must
  // not be able to put a newline, a quote or three kilobytes into either.
  const injected = middlewareRun({ 'x-request-id': 'a\r\nSet-Cookie: x=1' });
  assert.match(injected.seen ?? '', /^[0-9a-f]{10}$/);

  const huge = middlewareRun({ 'x-request-id': 'a'.repeat(500) });
  assert.match(huge.seen ?? '', /^[0-9a-f]{10}$/);
});

test('two requests do not share an id', () => {
  assert.notEqual(middlewareRun().seen, middlewareRun().seen);
});

// ── The lines ───────────────────────────────────────────────────────────

/** Captures what the logger actually writes to stdout. */
function captureJson(work: (logger: StructuredLogger) => void): string[] {
  const lines: string[] = [];
  const original = process.stdout.write.bind(process.stdout);
  (process.stdout as { write: unknown }).write = ((chunk: string) => {
    lines.push(String(chunk));
    return true;
  }) as never;
  try {
    work(new StructuredLogger('Test', true));
  } finally {
    (process.stdout as { write: unknown }).write = original;
  }
  return lines.map((line) => line.trim()).filter(Boolean);
}

test('a line is one JSON object carrying its request', () => {
  const lines = captureJson((logger) => {
    runWithRequestContext(
      {
        requestId: 'abc1234567',
        method: 'POST',
        route: '/orders/checkout',
        userId: 'user-1',
        role: 'CUSTOMER',
        startedAt: Date.now(),
      },
      () => logger.log('order placed'),
    );
  });

  assert.equal(lines.length, 1);
  const line = JSON.parse(lines[0]);
  assert.equal(line.message, 'order placed');
  assert.equal(line.requestId, 'abc1234567');
  assert.equal(line.route, '/orders/checkout');
  assert.equal(line.userId, 'user-1');
  assert.equal(line.level, 'log');
});

test('a line outside any request still logs', () => {
  const lines = captureJson((logger) => logger.log('nightly sweep'));
  const line = JSON.parse(lines[0]);
  assert.equal(line.message, 'nightly sweep');
  assert.equal(
    line.requestId,
    undefined,
    'a cron has no request, and that is not a reason to lose the line',
  );
});

// ── What never reaches a log ────────────────────────────────────────────

test('credentials and phone numbers are redacted at any depth', () => {
  const lines = captureJson((logger) =>
    logger.log({
      ok: 'visible',
      password: 'hunter2',
      nested: { refreshToken: 'abc', phone: '+963900000000' },
      list: [{ apiKey: 'k' }],
    }),
  );

  const raw = lines[0];
  assert.ok(!raw.includes('hunter2'));
  assert.ok(!raw.includes('+963900000000'));
  assert.ok(!raw.includes('abc'));
  assert.ok(raw.includes('visible'), 'and everything else is still there');
});

test('a phone number is treated as a credential, because here it is one', () => {
  // Sign-in on this platform is a code sent to her number. A number in a log
  // is most of what somebody needs.
  const lines = captureJson((logger) => logger.log({ phone: '+963911111111' }));
  assert.match(lines[0], /\[redacted\]/);
});
