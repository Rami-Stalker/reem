import {
  Controller,
  Get,
  Header,
  Logger,
  NotFoundException,
  OnApplicationBootstrap,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OtpStatus } from '@prisma/client';
import { Public } from '../../../common/decorators/public.decorator';
import { PrismaService } from '../../../prisma/prisma.service';
import { OtpCipherService } from './otp-cipher.service';

/**
 * A local stand-in for the SMS aggregator, until one is contracted.
 *
 * **Why this exists at all.** Every transport slot is empty — WhatsApp needs an
 * approved template, SMS needs a signed Syrian aggregator — so no code reaches
 * a real handset today. That was survivable while a password could sign you in.
 * It is not survivable now: sign-in is a code, and a password on a handset the
 * account has never used falls through to a code as well. Without a readable
 * delivery surface the platform is not merely inconvenient to test, it is
 * **impossible to enter** — including for the first admin, who cannot read the
 * ops console because reading it requires the sign-in she is trying to perform.
 *
 * So this is the missing half of the ops-console transport: that transport
 * already accepts a challenge and deliberately keeps the code readable
 * (`retainCode`), and the admin endpoint already reveals it — to a session that
 * cannot exist yet. This endpoint reveals the same codes with no session at all.
 *
 * **What keeps it honest.** It is the same bounded compromise as `OTP_DEV_ECHO`,
 * with the same three guards:
 *
 * - it must be switched on explicitly with `OTP_DEV_INBOX_ENABLED=true`;
 * - the environment validator **refuses to boot** with that flag when
 *   `NODE_ENV=production`, and this controller independently refuses to serve
 *   in production even if the validator were bypassed;
 * - when it is off — which is the default, and always in production — the
 *   routes answer 404 rather than 403, so a probe cannot learn it exists.
 *
 * It writes no security event per read, unlike the admin reveal. That is
 * deliberate and is the reason it is dev-only rather than a beta feature: an
 * auto-refreshing page would write a CRITICAL event every two seconds and bury
 * the real ones. The audit trail for this surface is that it cannot run in
 * production at all.
 *
 * **Delete this when the aggregator contract lands.** Nothing else depends on
 * it: remove the controller, the flag, and the `.env` line.
 */
@Controller('auth/dev')
export class DevInboxController implements OnApplicationBootstrap {
  private readonly logger = new Logger(DevInboxController.name);
  private readonly enabled: boolean;

  constructor(
    private readonly prisma: PrismaService,
    private readonly cipher: OtpCipherService,
    config: ConfigService,
  ) {
    this.enabled =
      config.get<boolean>('otpDelivery.devInboxEnabled') === true &&
      config.get<string>('nodeEnv') !== 'production';
  }

  onApplicationBootstrap(): void {
    if (!this.enabled) return;
    // Loud, once, at boot. Somebody who inherits this environment should not
    // have to read the config to discover that plaintext codes are being served
    // to anyone who can reach the port.
    this.logger.warn(
      'OTP dev inbox is ENABLED — one-time codes are readable without a session ' +
        'at GET /auth/dev/inbox. Development only; remove once an SMS provider is contracted.',
    );
  }

  /** The codes currently outstanding, newest first. */
  @Public()
  @Get('inbox')
  async inbox() {
    return { messages: await this.pending() };
  }

  /**
   * The same list as a page that refreshes itself.
   *
   * Worth the markup: the realistic way to test the app is on a handset with
   * this open on a laptop beside it, and re-running a curl command between
   * every step makes a two-code journey like a phone change genuinely painful.
   */
  @Public()
  @Get('inbox.html')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async inboxPage(): Promise<string> {
    const messages = await this.pending();
    const rows = messages
      .map(
        (message) => `
        <tr>
          <td class="code">${message.code ?? '—'}</td>
          <td class="match">${message.match_code ?? '—'}</td>
          <td dir="ltr">${escapeHtml(message.destination)}</td>
          <td>${escapeHtml(message.purpose)}</td>
          <td class="dim">${message.expires_in_seconds}s</td>
        </tr>`,
      )
      .join('');

    return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta http-equiv="refresh" content="3">
<title>Reem — dev inbox</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 15px/1.5 system-ui, sans-serif; margin: 2rem auto; max-width: 46rem; padding: 0 1rem; }
  h1 { font-size: 1.1rem; margin: 0 0 .25rem; }
  p.note { color: #b45309; margin: 0 0 1.5rem; font-size: .85rem; }
  table { border-collapse: collapse; width: 100%; }
  th, td { text-align: start; padding: .5rem .6rem; border-bottom: 1px solid #8883; }
  th { font-size: .75rem; text-transform: uppercase; letter-spacing: .04em; opacity: .6; font-weight: 600; }
  .code { font: 700 1.4rem ui-monospace, monospace; letter-spacing: .12em; }
  .match { font: 600 1rem ui-monospace, monospace; opacity: .75; }
  .dim { opacity: .6; font-variant-numeric: tabular-nums; }
  .empty { opacity: .6; padding: 2rem 0; }
</style></head>
<body>
  <h1>Reem — one-time codes (development)</h1>
  <p class="note">No SMS provider is contracted yet, so codes are shown here instead of being delivered.
  This page cannot run in production.</p>
  ${
    messages.length === 0
      ? '<p class="empty">Nothing outstanding. Ask for a code in the app.</p>'
      : `<table>
    <thead><tr><th>Code</th><th>Match</th><th>To</th><th>Purpose</th><th>Expires</th></tr></thead>
    <tbody>${rows}</tbody>
  </table>`
  }
</body></html>`;
  }

  /**
   * Outstanding challenges with their plaintext codes.
   *
   * Only rows the outbox still holds a sealed code for, which means: not yet
   * used, not yet expired. A consumed code is shredded by the dispatcher, so
   * this list cannot show one that has already been spent.
   */
  private async pending() {
    if (!this.enabled) {
      // 404, not 403 — a disabled surface should be indistinguishable from one
      // that was never built.
      throw new NotFoundException();
    }

    const rows = await this.prisma.otpOutbox.findMany({
      where: {
        sealedCode: { not: null },
        challenge: {
          status: OtpStatus.PENDING,
          expiresAt: { gt: new Date() },
        },
      },
      include: { challenge: true },
      orderBy: { createdAt: 'desc' },
      take: 25,
    });

    const now = Date.now();
    return rows.map((row) => ({
      destination: row.challenge.destination,
      purpose: row.challenge.purpose.toLowerCase(),
      code: this.open(row.sealedCode),
      match_code: row.challenge.matchCode,
      expires_in_seconds: Math.max(
        0,
        Math.round((row.challenge.expiresAt.getTime() - now) / 1000),
      ),
      requested_at: row.challenge.createdAt.toISOString(),
    }));
  }

  /** A code that will not open is reported as absent, never as a crash. */
  private open(sealed: string | null): string | null {
    if (!sealed) return null;
    try {
      return this.cipher.open(sealed);
    } catch {
      return null;
    }
  }
}

function escapeHtml(value: string): string {
  return value.replace(
    /[&<>"']/g,
    (character) =>
      ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;',
      })[character] as string,
  );
}
