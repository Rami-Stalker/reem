import { ConsoleLogger, LogLevel } from '@nestjs/common';

import { currentRequestContext } from './request-context';

/**
 * Keys whose values never reach a log line, whatever wrote them.
 *
 * Matched case-insensitively as substrings, the same list the audit trail
 * uses, because the two failures are the same failure: a log is a store, and
 * a store nobody guards is the one that leaks.
 */
const REDACT = [
  'password',
  'token',
  'secret',
  'otp',
  'pin',
  'apikey',
  'api_key',
  'signature',
  'authorization',
  'phone',
];

/**
 * One JSON object per line, with the request it belongs to attached.
 *
 * **What this replaces.** Nest's default logger writes a coloured sentence.
 * That reads well over somebody's shoulder and is close to useless afterwards:
 * nothing ties a warning to the request that caused it, so "the customer says
 * her order failed at about four" turns into reading a wall of interleaved
 * lines from every concurrent request and guessing. The platform serves one
 * process today, which makes the interleaving *worse* rather than better —
 * every customer's work is in the same stream.
 *
 * So each line is an object, and it carries `requestId` — the same id the
 * error response hands the customer. She reads it off the screen, support
 * pastes it into a search, and every line of that request comes back.
 *
 * **Development keeps the readable format**, because a developer with one
 * request in flight does not need JSON and does need to see it at a glance.
 * The switch is `LOG_FORMAT`, and production defaults to `json`.
 *
 * **Nothing here is a log aggregator.** It is one line per event on stdout,
 * which is what a single-instance deployment can actually use and what any
 * collector will accept later without the code changing again.
 */
export class StructuredLogger extends ConsoleLogger {
  constructor(
    context?: string,
    private readonly json: boolean = process.env.LOG_FORMAT === 'json',
  ) {
    super(context ?? 'App');
  }

  protected printMessages(
    messages: unknown[],
    context = '',
    logLevel: LogLevel = 'log',
  ): void {
    if (!this.json) {
      // The pretty path, unchanged. `super` owns the colours and the layout.
      super.printMessages(messages as never, context, logLevel);
      return;
    }

    const request = currentRequestContext();
    for (const message of messages) {
      const line: Record<string, unknown> = {
        at: new Date().toISOString(),
        level: logLevel,
        context: context || this.context || undefined,
        // Redacted **before** rendering, not after. Stringifying first and
        // then scrubbing the line would only ever see one long string, so a
        // password nested three levels down inside a logged object went
        // straight through — which is exactly what happened.
        message: this.render(this.redact(message)),
      };

      if (request) {
        line.requestId = request.requestId;
        line.method = request.method;
        line.route = request.route;
        // The account, not the person: an id joins to the user table for
        // somebody who is entitled to look, and says nothing to anyone else.
        if (request.userId) line.userId = request.userId;
        if (request.role) line.role = request.role;
      }

      process.stdout.write(`${JSON.stringify(this.redact(line))}\n`);
    }
  }

  private render(message: unknown): string {
    if (typeof message === 'string') return message;
    if (message instanceof Error) return message.stack ?? message.message;
    try {
      return JSON.stringify(message);
    } catch {
      return String(message);
    }
  }

  /**
   * Drops anything that looks like a credential or a phone number, at any
   * depth.
   *
   * A phone number is in the list because on this platform it *is* the
   * identity: sign-in is a code sent to it, so a number in a log is most of
   * what an attacker needs. `PiiRedactor` does the same job for crash reports
   * on the client; this is the server half.
   */
  private redact(value: unknown, depth = 0): unknown {
    if (depth > 6 || value === null || typeof value !== 'object') return value;
    if (Array.isArray(value)) {
      return value.map((item) => this.redact(item, depth + 1));
    }
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([key, item]) => {
        const banned = REDACT.some((word) => key.toLowerCase().includes(word));
        return [key, banned ? '[redacted]' : this.redact(item, depth + 1)];
      }),
    );
  }
}
